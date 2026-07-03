package flixel.graphics.textures;

import flixel.graphics.FlxBitmap;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.utils.UInt8Array;
import flixel.system.render.FlxRendererTypes;

// TODO, once it's possible:
// - add a format enum?
// - mipmapping?

/**
 * Represents a GPU texture used for rendering.
 * While it is a reference to a GPU texture at its core, `FlxTexture` also provides some helper
 * methods to allow for easier read & write operations.
 * 
 * ### Reading texture pixels
 * There are two options for reading pixels from a texture:
 * 1. Use the `texture.readPixels[...]()` method to read the pixels of the texture (or a specified region) into a specific user managed buffer.
 * 2. Use the `texture.downloadBitmap()` method to read the entire texture into an internal `FlxBitmap`. The bitmap is managed internally by the texture.
 *    Any changes made to the provided bitmap will be applied to the texture once `texture.sync()` is called. You can also optionally destroy the
 *    internal bitmap when applying changes, to free memory.
 */
class FlxTexture implements IFlxDestroyable
{
    /**
     * The default value of the `readable` parameter in the upload methods.
     * Defaults to `true` for backwards compatibility.
     * 
     * When targeting Flash, or using the blitting renderer, this value must always be 
     * true and will warn if you attempt to change it.
     */
    public static var defaultReadable(default, set):Bool = true;

    static function set_defaultReadable(value:Bool):Bool
    {
        #if flash
        FlxG.log.warn("FlxTexture.defaultReadable can only be true when targeting Flash.");
        return true;
        #else 
        if (FlxG.renderer.blit)
        {
            FlxG.log.warn("FlxTexture.defaultReadable can only be true when using the blitting renderer.");
            return true;
        }

        return defaultReadable = value;
        #end
    }

    // TODO: expose in 7.0.0 once sprite.antialiasing is removed
    /**
     * The initial value of `texture.filter`, for all textures.
     * Defaults to `NEAREST`.
     */
    // public static var defaultFilter:FlxTextureFilter = NEAREST;

    /**
     * Creates a `FlxTexture` and uploads pixel data to it from the provided `bitmap`.
     * 
     * @param   bitmap     The `FlxBitmap` to upload data from.
     * @param   readable   Whether the bitmap should be kept, to allow for read/write operations.
     *                     Set this to `true` if you plan on constantly read/writing pixels, otherwise
     *                     set it to `false` for a noticable decrease in memory usage.
     * @return  The newly created `FlxTexture`.
     */
    public static function fromBitmap(bitmap:FlxBitmap, ?readable:Bool):FlxTexture
    {
        var texture:FlxTexture = new FlxTexture(bitmap.width, bitmap.height);
        texture.uploadBitmap(bitmap, readable);
        return texture;
    }

    /**
     * The current status of the texture.
     */
    public var status(get, null):FlxTextureStatus;

    /**
     * The width of the texture, in pixels.
     */
    public var width(default, null):Int;

    /**
     * The height of the texture, in pixels.
     */
    public var height(default, null):Int;

    /**
     * The texture wrapping mode for the horizontal (U) axis. 
     * Default value is `CLAMP`.
     * 
     * @see `FlxTextureWrap`
     */
    public var wrapU(default, set):FlxTextureWrap = CLAMP;

    /**
     * The texture wrapping mode for the vertical (V) axis. 
     * Default value is `CLAMP`.
     * 
     * @see `FlxTextureWrap`
     */
    public var wrapV(default, set):FlxTextureWrap = CLAMP;

    // TODO: expose in 7.0.0 once sprite.antialiasing is removed
    /**
     * The texture filtering mode used when scaling the texture.
     * 
     * @see `FlxTextureFilter`
     */
    // public var filter(default, set):FlxTextureFilter = defaultFilter;

    /**
     * The underlying representation of the texture, you probably shouldn't mess with this!
     * The actual type varies depending on the used renderer backend. 
     */
    var _handle:Null<FlxTextureHandle>;

    /**
     * Reference to the internal bitmap, which is used to allow read/write operations when the texture is readable.
     */
    var _bitmap:Null<FlxBitmap>;

    /**
     * Helper, used to track changes between the internal bitmap and the texture.
     */
    var _version:Int;

    /**
     * Helper to indicate whether the texture was uploaded once.
     * Used by some renderers to make subsequent uploads faster.
     */
    var _allocated:Bool = false;

    /**
     * Creates a new `FlxTexture` instance. 
     * The texture is NOT ready to be used yet, make sure to upload data to it before using it.
     * 
     * @param   width    The width of the texture, in pixels.
     * @param   height   The height of the texture, in pixels.
     */
    public function new(width:Int, height:Int)
    {
        this.width = width;
        this.height = height;
        status = INVALID;

        if (width <= 0 || height <= 0)
            FlxG.log.error('Invalid texture dimensions (${width}x${height})');

        final max = FlxG.renderer.maxTextureSize;
        if (max > 0)
        {
        	if (width > max || height > max)
        		FlxG.log.error('Texture dimensions (${width}x${height}) exceed the maximum allowed size (${max}x${max})');
        }

        _handle = FlxG.renderer.textures.createHandle();

        // Invoke the setters to properly set up the texture state
        set_wrapU(wrapU);
        set_wrapV(wrapV);
        // set_filter(filter);
    }

    /**
     * Destroys all data related to this texture.
     */
    public function destroy():Void 
    {
        if (_handle != null)
        {
            FlxG.renderer.textures.destroyHandle(_handle);
            _handle = null;
        }

        if (_bitmap != null)
        {
            _bitmap.destroy();
            _bitmap = null;
        }

        status = INVALID;
    }

    /**
     * Check whether the current texture status allows for read/write operations, and log if it doesn't.
     * @return  Whether the current texture status allows for read/write operations
     */
    public function checkReadWrite():Bool
    {
        if (status.match(INVALID))
        {
            FlxG.log.error("Cannot perform read/write operations on invalid texture.");
            return false;
        }
        else if (!status.match(READABLE(_)))
        {
            FlxG.log.error("Cannot perform read/write operations on VRAM-only texture. Use texture.downloadBitmap() to fetch pixel data back from the GPU, first.");
            return false;
        }

        return true;
    }

    /**
     * Uploads texture data from a `FlxBitmap`.
     * The bitmap should match the texture in size.
     * 
     * @param   bitmap     The `FlxBitmap` to upload data from.
     * @param   readable   Whether the bitmap should be kept, to allow for read/write operations.
     *                     Set this to `true` if you plan on constantly read/writing pixels, otherwise
     *                     set it to `false` for a noticable decrease in memory usage.
     */
    public function uploadBitmap(bitmap:FlxBitmap, ?readable:Bool):Void 
    {
        if (readable == null)
            readable = defaultReadable;

        FlxG.renderer.textures.uploadBitmap(this, bitmap);
        #if !flash
        _version = bitmap.readable ? bitmap.image.version : 0;
        #end

        if (!_allocated)
            _allocated = true;

        // Clean up previous bitmap
        if (_bitmap != null)
            destroyBitmap();

        if (readable || FlxG.renderer.blit)
        {
            _bitmap = bitmap;
            status = READABLE(true);
        }
        #if FLX_RENDER_DRAWQUADS
        else if (!readable)
        {
            _handle.disposeImage();
            status = HARDWARE;
        }
        #end
    }

    /**
     * Reads the texture pixels into a `UInt8Array` buffer.
     * The read pixels will be in `RGBA` format.
     * 
     * @param   rect     Optional, the region of the texture to read from. If left
     *                   unspecified, the entire texture is read.
     * @param   buffer   Optional, the buffer to read into. Must be `width * height * 4` bytes long.
     *                   If left null, a new one will be created.
     * @return  A `UInt8Array` buffer containing the pixels.
     */
    public function readPixels(?rect:FlxRect, ?buffer:UInt8Array):UInt8Array
    {
        if (rect == null)
            rect = FlxRect.weak(0, 0, this.width, this.height);

        if (buffer == null)
            buffer = new UInt8Array(Std.int(rect.width * rect.height * 4));

        FlxG.renderer.textures.readPixels(this, buffer, rect);
        rect.putWeak();
        return buffer;
    }

    /**
     * Immediately destroys the internal bitmap, while keeping the VRAM texture.
     * This greatly reduces RAM usage, at the cost of not being able to read/write pixels.
     * You can always recover the internal bitmap by calling `texture.downloadBitmap()`.
     * 
     * This method does nothing when using the blitting renderer, as it always requires the internal bitmap.
     * 
     * **NOTE:** If you want to apply the changes made to the bitmap before destroying it you should use
     * `texture.sync(true);` instead!
     */
    public function destroyBitmap():Void
    {
        if (FlxG.renderer.blit)
            return;

        if (_bitmap != null)
        {
            FlxG.renderer.textures.destroyBitmap(_bitmap);
            _bitmap = null;       
            status = HARDWARE;
        }   
    }

    /**
     * Returns a `FlxBitmap` instance associated with this texture.
     * 
     * `FlxBitmap` provides methods to read and manipulate the pixel data of the image.
	 * After you're done editing the bitmap, you must call `texture.sync()` in order to apply the changes
     * and update the hardware texture.
     * 
     * If the texture's status is `HARDWARE`, the pixel data will be downloaded from the GPU.
     * This can be a very slow operation, so it's recommended to not do it often.
     * 
     * **NOTE:** This function is not thread-safe, and should only be called on the main thread!
     * 
     * @return   A `FlxBitmap` containing the pixel data of this texture.
     */
    public function downloadBitmap():FlxBitmap 
    {
        if (_bitmap == null)
        {
            final pixels = readPixels();

            #if (FLX_RENDER_DRAWQUADS && !flash)
            if (FlxG.renderer.tile)
            {
                var image = new Image(new ImageBuffer(pixels, width, height, 32, RGBA32));
                @:privateAccess _handle.__fromImage(image);
                _handle.image.version = _version;

                _bitmap = _handle;
            }
            else
            #end
            {
                _bitmap = FlxBitmap.fromBytes(pixels.toBytes());
                #if !flash
                _bitmap.image.version = _version;
                #end
            }

            status = READABLE(true);
        }

        return _bitmap;
    }

    /**
	 * Updates the texture based on the changes made to the bitmap, synchronising the two.
     * 
     * This method does nothing when using the blitting renderer, as it always requires the internal bitmap.
     * 
     * **NOTE:** This function is not thread-safe, and should only be called on the main thread!
     * 
     * @param   destroyBitmap   Whether the internal bitmap should be destroyed. Set this to `true`
	 *                          if you don't plan on read/writing pixels afterwards, for a noticeable decrease in memory usage.
     *                          You can always get a reference to the bitmap back via `texture.downloadBitmap()`.
     */
	public function sync(destroyBitmap:Bool = false) 
    {
        if (FlxG.renderer.blit)
            return;

        if (_bitmap != null)
            uploadBitmap(_bitmap, !destroyBitmap);
    }

    /**
     * Clones this texture and returns a brand new instance.
     * 
     * **NOTE:** This function is not thread-safe, and should only be called on the main thread!
     * 
     * @return FlxTexture
     */
    public function clone():FlxTexture
    {
        var pixels:FlxBitmap = null;

        switch (status)
        {
            case READABLE(synced):
                pixels = downloadBitmap();

                // DRAW_QUADS / BLIT uses the underlying bitmap as the handle,
                // so for a fresh copy we want to clone it.
                if (FlxG.renderer.blit #if FLX_RENDER_DRAWQUADS || true #end)
                    pixels = pixels.clone();

            default:
                pixels = FlxBitmap.fromBytes(readPixels().toBytes());
        }

        var texture = new FlxTexture(width, height);
        texture.uploadBitmap(pixels);
        return texture;
    }

    /**
	 * `FlxBitmap` synced the bitmap and texture automatically while `FlxTexture` requires you to manually apply your changes.
     * This is called by draw methods to avoid a breaking change between the two, and should be removed in the next major version.
     */
    @:allow(flixel.system.render)
	@:noCompletion function syncIfNeeded():Void
    {
        switch (status)
        {
            case READABLE(synced):
                if (!synced)
                {
					FlxG.log.warn("Automatic texture-bitmap syncing is deprecated and will be removed in the next major version. Use texture.sync() to apply changes made to the texture's bitmap.");
					sync(false);
                }

            default:
        }
    }

    inline function get_status():FlxTextureStatus
    {
        #if !flash
        if (!FlxG.renderer.blit && _bitmap != null && _bitmap.image != null && _bitmap.image.version > _version)
            status = READABLE(false);
        #end

        return status;
    }

    function set_wrapU(value:FlxTextureWrap):FlxTextureWrap 
    {
        if (wrapU != value)
        {
            FlxG.renderer.textures.setWrapU(this, value);
            wrapU = value;
        }
        return value;
    }

    function set_wrapV(value:FlxTextureWrap):FlxTextureWrap 
    {
        if (wrapV != value)
        {
            FlxG.renderer.textures.setWrapV(this, value);
            wrapV = value;
        }
        return value;
    }

    // TODO: expose in 7.0.0 once sprite.antialiasing is removed
    // function set_filter(value:FlxTextureFilter):FlxTextureFilter 
    // {
    //     if (filter != value)
    //     {
    //         FlxG.renderer.setTextureFilter(this, value);
    //         filter = value;
    //     }
    //     return value;
    // }
}

/**
 * An enum representing the current status of the texture.
 */
enum FlxTextureStatus
{
    /**
     * The texture has no data.
     */
    INVALID;

    /**
     * The texture exists in RAM and can be read and edited.
     * 
     * @param   synced   Whether the texture and its bitmap are synced (have the same pixel data).
     */
    READABLE(synced:Bool);

    /**
     * The texture only exists in VRAM.
     * 
     * It can't be read from, or edited, without calling `texture.downloadBitmap()` first
     * to download the pixel data back from the GPU.
     */
    HARDWARE;
}

/**
 * An enum representing the wrapping mode of the texture.
 * In other words, determines how the texture should be sampled when accessing texture coordinates
 * outside of the normalized bounds (0...1).
 */
enum FlxTextureWrap
{
    /**
     * Clamps the texture to the last pixel at the edge.
     */
    CLAMP;

    /**
     * Repeats (tiles) the texture.
     */
    REPEAT;

    // MIRRORED_REPEAT;
}

// TODO: expose in 7.0.0 once sprite.antialiasing is removed
/**
 * The texture filtering mode used when scaling the texture.
 */
// enum FlxTextureFilter
// {
//     /**
//      * Picks the pixel closest to the current texture coordinate. Produces a sharp, pixelated look.
//      */
//     NEAREST;

//     /**
//      * Interpolates between the neighbouring pixels at the current texture coordinate. Produces a blurry, smooth (antialiased) look.
//      */
//     LINEAR;
// }
