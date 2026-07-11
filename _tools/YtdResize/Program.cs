using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using BCnEncoder.Encoder;
using BCnEncoder.ImageSharp;
using BCnEncoder.Shared;
using CodeWalker.GameFiles;
using CodeWalker.Utils;
using ImageSharpImage = SixLabors.ImageSharp.Image;
using DrawingRectangle = System.Drawing.Rectangle;
using DrawingPixelFormat = System.Drawing.Imaging.PixelFormat;
using SixLabors.ImageSharp.PixelFormats;

namespace YtdResize
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            var streamDir = args.Length > 0
                ? args[0]
                : Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "resources", "[mlo]", "[mlo_pack_3]", "cfx-nteam-mrpd", "stream");

            streamDir = Path.GetFullPath(streamDir);
            if (!Directory.Exists(streamDir))
            {
                Console.Error.WriteLine("Folder not found: " + streamDir);
                return 1;
            }

            var files = Directory.GetFiles(streamDir, "nteammrpdtxt*.ytd");
            if (files.Length == 0)
            {
                Console.Error.WriteLine("No nteammrpdtxt*.ytd files in " + streamDir);
                return 1;
            }

            var backupDir = Path.Combine(streamDir, "_backup_before_resize");
            Directory.CreateDirectory(backupDir);

            var totalResized = 0;
            foreach (var file in files.OrderBy(f => f))
            {
                var name = Path.GetFileName(file);
                var backup = Path.Combine(backupDir, name);
                if (!File.Exists(backup))
                    File.Copy(file, backup, false);

                var before = new FileInfo(file).Length;
                var resized = ProcessYtd(file);
                totalResized += resized;
                var after = new FileInfo(file).Length;
                Console.WriteLine("{0}: resized {1} textures, {2}KB -> {3}KB", name, resized, before / 1024, after / 1024);
            }

            Console.WriteLine("Done. Total textures resized: " + totalResized);
            Console.WriteLine("Backups: " + backupDir);
            return 0;
        }

        private static int ProcessYtd(string path)
        {
            var data = File.ReadAllBytes(path);
            var ytd = new YtdFile();
            ytd.Load(data);
            ytd.Name = Path.GetFileName(path);

            var dict = ytd.TextureDict;
            if (dict?.Textures?.data_items == null)
                return 0;

            var textures = new List<Texture>(dict.Textures.data_items);
            var count = 0;

            for (var i = 0; i < textures.Count; i++)
            {
                var tex = textures[i];
                if (tex.Width < 1024 && tex.Height < 1024)
                    continue;

                var nw = Math.Max(1, tex.Width / 2);
                var nh = Math.Max(1, tex.Height / 2);
                if (nw == tex.Width && nh == tex.Height)
                    continue;

                try
                {
                    var replacement = ResizeTexture(tex, nw, nh);
                    replacement.Name = tex.Name;
                    replacement.NameHash = tex.NameHash;
                    replacement.Usage = tex.Usage;
                    replacement.UsageFlags = tex.UsageFlags;
                    replacement.Unknown_32h = tex.Unknown_32h;
                    textures[i] = replacement;
                    count++;
                    Console.WriteLine("  " + tex.Name + ": " + tex.Width + "x" + tex.Height + " -> " + nw + "x" + nh);
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine("  SKIP " + tex.Name + ": " + ex.Message);
                }
            }

            if (count == 0)
                return 0;

            dict.BuildFromTextureList(textures);
            File.WriteAllBytes(path, ytd.Save());
            return count;
        }

        private static Texture ResizeTexture(Texture src, int newW, int newH)
        {
            var pixels = DDSIO.GetPixels(src, 0);
            if (pixels == null || pixels.Length == 0)
                throw new InvalidOperationException("no pixel data");

            using (var bmp = new Bitmap(src.Width, src.Height, DrawingPixelFormat.Format32bppArgb))
            {
                var rect = new DrawingRectangle(0, 0, src.Width, src.Height);
                var bd = bmp.LockBits(rect, ImageLockMode.WriteOnly, bmp.PixelFormat);
                try
                {
                    Marshal.Copy(pixels, 0, bd.Scan0, pixels.Length);
                }
                finally
                {
                    bmp.UnlockBits(bd);
                }

                using (var scaled = new Bitmap(newW, newH, DrawingPixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(scaled))
                {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.DrawImage(bmp, 0, 0, newW, newH);

                    var outPixels = new byte[newW * newH * 4];
                    var srect = new DrawingRectangle(0, 0, newW, newH);
                    var sbd = scaled.LockBits(srect, ImageLockMode.ReadOnly, scaled.PixelFormat);
                    try
                    {
                        Marshal.Copy(sbd.Scan0, outPixels, 0, outPixels.Length);
                    }
                    finally
                    {
                        scaled.UnlockBits(sbd);
                    }

                    var dds = BuildCompressedDds(outPixels, newW, newH, src.Format);
                    var tex = DDSIO.GetTexture(dds);
                    return tex;
                }
            }
        }

        private static bool HasAlpha(byte[] rgba)
        {
            for (var i = 3; i < rgba.Length; i += 4)
            {
                if (rgba[i] < 255)
                    return true;
            }
            return false;
        }

        private static CompressionFormat MapCompressionFormat(TextureFormat format, bool hasAlpha)
        {
            switch (format)
            {
                case TextureFormat.D3DFMT_DXT1: return CompressionFormat.Bc1;
                case TextureFormat.D3DFMT_DXT3: return CompressionFormat.Bc2;
                case TextureFormat.D3DFMT_DXT5: return CompressionFormat.Bc3;
                case TextureFormat.D3DFMT_ATI1: return CompressionFormat.Bc4;
                case TextureFormat.D3DFMT_ATI2: return CompressionFormat.Bc5;
                case TextureFormat.D3DFMT_BC7: return CompressionFormat.Bc7;
                default: return hasAlpha ? CompressionFormat.Bc3 : CompressionFormat.Bc1;
            }
        }

        private static byte[] BuildCompressedDds(byte[] rgba, int w, int h, TextureFormat sourceFormat)
        {
            using (var image = ImageSharpImage.LoadPixelData<Rgba32>(rgba, w, h))
            {
                var encoder = new BcEncoder
                {
                    OutputOptions =
                    {
                        Format = MapCompressionFormat(sourceFormat, HasAlpha(rgba)),
                        FileFormat = OutputFileFormat.Dds,
                        GenerateMipMaps = true,
                        Quality = CompressionQuality.Balanced,
                    }
                };

                using (var ms = new MemoryStream())
                {
                    encoder.EncodeToStream(image, ms);
                    return ms.ToArray();
                }
            }
        }
    }
}
