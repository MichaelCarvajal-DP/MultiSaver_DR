using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Drawing;

namespace MultiSaver.ConfigData
{
    /// <summary>
    /// Helper para clasificar imágenes por orientación (horizontal/vertical)
    /// </summary>
    public static class ImageHelper
    {
        private static readonly string[] SupportedExtensions = { ".jpg", ".jpeg", ".png", ".bmp", ".gif" };

        /// <summary>
        /// Obtiene todos los archivos de imagen soportados en una carpeta
        /// </summary>
        public static List<string> GetImageFiles(string folderPath)
        {
            if (!Directory.Exists(folderPath))
                return new List<string>();

            try
            {
                return Directory.GetFiles(folderPath)
                    .Where(f => SupportedExtensions.Contains(Path.GetExtension(f).ToLower()))
                    .ToList();
            }
            catch
            {
                return new List<string>();
            }
        }

        /// <summary>
        /// Clasifica imágenes en carpetas horizontal/vertical basado en sus dimensiones
        /// </summary>
        public static void ClassifyImages(string sourceFolder, string targetBaseFolder)
        {
            if (!Directory.Exists(sourceFolder))
                return;

            string horizontalFolder = Path.Combine(targetBaseFolder, "horizontal");
            string verticalFolder = Path.Combine(targetBaseFolder, "vertical");

            Directory.CreateDirectory(horizontalFolder);
            Directory.CreateDirectory(verticalFolder);

            var imageFiles = GetImageFiles(sourceFolder);

            foreach (var imagePath in imageFiles)
            {
                try
                {
                    var orientation = GetImageOrientation(imagePath);
                    string targetFolder = orientation == ImageOrientation.Vertical ? verticalFolder : horizontalFolder;
                    string targetPath = Path.Combine(targetFolder, Path.GetFileName(imagePath));

                    // Evitar duplicados y overwrite solo si el archivo cambió
                    if (File.Exists(targetPath))
                    {
                        var sourceInfo = new FileInfo(imagePath);
                        var targetInfo = new FileInfo(targetPath);
                        if (sourceInfo.Length == targetInfo.Length && 
                            sourceInfo.LastWriteTime == targetInfo.LastWriteTime)
                            continue;
                    }

                    File.Copy(imagePath, targetPath, true);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error clasificando imagen {imagePath}: {ex.Message}");
                }
            }
        }

        /// <summary>
        /// Determina la orientación de una imagen analizando sus dimensiones
        /// </summary>
        public static ImageOrientation GetImageOrientation(string imagePath)
        {
            try
            {
                using (Image image = Image.FromFile(imagePath))
                {
                    // Considerar rotación EXIF si existe
                    try
                    {
                        if (image.PropertyIdList.Contains(0x0112)) // Orientación EXIF
                        {
                            var prop = image.GetPropertyItem(0x0112);
                            int orientationValue = BitConverter.ToInt16(prop.Value, 0);
                            
                            // EXIF orientaciones:
                            // 1 = Normal, 2 = Horizontal flip, 3 = 180°, 4 = Vertical flip
                            // 5 = Horizontal flip + 90° CCW, 6 = 90° CW, 7 = Vertical flip + 90° CW, 8 = 90° CCW
                            if (orientationValue == 6 || orientationValue == 8)
                            {
                                // Imagen rotada 90°, invertir dimensiones
                                return image.Height > image.Width ? ImageOrientation.Horizontal : ImageOrientation.Vertical;
                            }
                        }
                    }
                    catch { }

                    // Clasificar por dimensiones
                    return image.Width > image.Height ? ImageOrientation.Horizontal : ImageOrientation.Vertical;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Error analizando imagen {imagePath}: {ex.Message}");
                return ImageOrientation.Horizontal; // Default
            }
        }

        /// <summary>
        /// Copia imágenes a carpetas horizontal/vertical sin crear archivos duplicados
        /// </summary>
        public static void OrganizeImagesIntoOrientationFolders(string imagesFolderPath)
        {
            if (!Directory.Exists(imagesFolderPath))
                return;

            string horizontalFolder = Path.Combine(imagesFolderPath, "horizontal");
            string verticalFolder = Path.Combine(imagesFolderPath, "vertical");

            Directory.CreateDirectory(horizontalFolder);
            Directory.CreateDirectory(verticalFolder);

            var imageFiles = GetImageFiles(imagesFolderPath);

            foreach (var imagePath in imageFiles)
            {
                // Skip si ya está en una carpeta de orientación
                string parentDir = Directory.GetParent(imagePath).Name.ToLower();
                if (parentDir == "horizontal" || parentDir == "vertical")
                    continue;

                try
                {
                    var orientation = GetImageOrientation(imagePath);
                    string targetFolder = orientation == ImageOrientation.Vertical ? verticalFolder : horizontalFolder;
                    string targetPath = Path.Combine(targetFolder, Path.GetFileName(imagePath));

                    if (!File.Exists(targetPath))
                    {
                        File.Copy(imagePath, targetPath, false);
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error organizando imagen {imagePath}: {ex.Message}");
                }
            }
        }
    }

    public enum ImageOrientation { Horizontal, Vertical }
}
