package flixel.system.render.gl;

import flixel.graphics.FlxMaterial;
import flixel.graphics.FlxTrianglesData;
import flixel.graphics.shaders.FlxShader;
import flixel.graphics.shaders.FlxBaseShader;
import flixel.math.FlxMatrix;
import lime.graphics.opengl.GL;
import lime.math.Matrix4;

// TODO ant: can we batch triangles?
@:access(flixel.graphics.FlxTrianglesData)
class FlxDrawTrianglesCommand extends FlxGLDrawCommand
{
	public static var defaultTexturedShader:FlxBaseShader = new FlxTexturedShader();

	public static var defaultColoredShader:FlxBaseShader = new FlxShader();

	public var data:FlxTrianglesData;

	/**
	 * Transformation matrix for this item on camera.
	 */
	public var matrix(default, set):FlxMatrix;

	// var _colors:UInt32Array = new UInt32Array();
	var _matrix4:Matrix4 = new Matrix4();

	public function new(renderer:FlxGLRenderer)
	{
		super(renderer);
		type = TRIANGLES;
	}

	override public function destroy():Void
	{
        super.destroy();

		data = null;
		_matrix4 = null;
		matrix = null;
	}

	// override public function prepare(context:GLContext, buffer:FlxRenderTexture, ?transform:FlxMatrix):Void
	// {
	// 	reset();
	// 	super.prepare(context, buffer, transform);
	// }

    function setShader(material:FlxMaterial):FlxBaseShader
    {
        var shader:FlxBaseShader = material.shader;

        if (shader == null)
            shader = textured ? defaultTexturedShader : defaultColoredShader;

        // GLHelper.useShader(shader);
        context.setShader(shader);
        this.shader = shader;

        return shader;
    }

	override function flush():Void
	{
		// init! init!
		// setContext(context);
		// context.checkRenderTarget(buffer);
		setShader(material);

		GLHelper.uniformMatrix4fv(shader.data.uMatrix.index, false, _matrix4);

		// material.apply(cast GL);

		context.setBlendMode(material.blendMode);

		if (textured)
		{
			context.setTextureSlot(0);
        	context.setTexture(graphic.bitmap, material.smoothing, material.getWrap());
			GL.uniform1i(shader.data.uImage0.index, 0);
            GL.uniform2f(shader.data.uTextureSize.index, graphic.width, graphic.height);
		}

		data.updateVertices();
		GL.vertexAttribPointer(shader.data.aPosition.index, 2, GL.FLOAT, false, 0, 0);
        GL.enableVertexAttribArray(shader.data.aPosition.index);

		if (textured)
		{
			// update the uvs
			data.updateUV();
			GL.vertexAttribPointer(shader.data.aTexCoord.index, 2, GL.FLOAT, false, 0, 0);
            GL.enableVertexAttribArray(shader.data.aTexCoord.index);
		}

		// TODO ant: if we REALLY want to keep color transform we could keep a helper colors array here,
		// multiply data.colors with the transform, and then feed that into the GPU as aColor...
		// update the colors
		data.updateColors();
		GL.vertexAttribPointer(shader.data.aColor.index, 4, GL.UNSIGNED_BYTE, true, 0, 0);
        GL.enableVertexAttribArray(shader.data.aColor.index);

		data.updateIndices();
		data.dirty = false;

		GL.drawElements(GL.TRIANGLES, data.indexCount, GL.UNSIGNED_SHORT, 0);

		FlxRenderer.totalDrawCalls++;
	}

	override function reset():Void
	{
		super.reset();
		data = null;
		_matrix4.identity();
	}

	@:noCompletion function set_matrix(value:FlxMatrix):FlxMatrix
	{
		if (value != null)
		{
			_matrix4.identity();
			_matrix4[0] = value.a;
			_matrix4[1] = value.b;
			_matrix4[4] = value.c;
			_matrix4[5] = value.d;
			_matrix4[12] = value.tx;
			_matrix4[13] = value.ty;
			_matrix4.append(renderer.projection);
		}

		return matrix = value;
	}
}
