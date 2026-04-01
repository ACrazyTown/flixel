package flixel.graphics;

import massive.munit.Assert;
import flixel.graphics.FlxBitmap;
import flixel.graphics.FlxTexture;

class FlxTextureTest extends FlxTest
{
    @Test
    function testStatus()
    {
        var texture = new FlxTexture(10, 10);
        Assert.areEqual(texture.status, INVALID);

        var bitmap = new FlxBitmap(10, 10, 0);
        texture.uploadBitmap(bitmap, true);
        Assert.areEqual(texture.status, READABLE(true));

        bitmap.setPixel(0, 0, 0xFFFFFFFF);
        Assert.areEqual(texture.status, READABLE(false));

        texture.apply(true);
        Assert.areEqual(texture.status, HARDWARE);
    }
}
