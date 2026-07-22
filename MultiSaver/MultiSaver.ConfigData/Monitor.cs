using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Drawing;

namespace MultiSaver.ConfigData
{
    
    public class Monitor
    {

        public string ID;

        public int IDNumber
        {

            get
            {

                return Convert.ToInt32(ID.Replace("\\\\.\\DISPLAY", ""));

            }

        }

        public Rectangle Bounds;

        public String Mode = "Unassigned";

        public String TransitionMode = "Random";
        public String Source;
        public String Order = "Random";

        public String TileType = "Random";
        public int FixedTiles = 10;
        public int MinTiles = 10;
        public int MaxTiles = 25;

        public String TransitionTime = "Random";
        public int FixedTime = 10;
        public int MinTime = 10;
        public int MaxTime = 25;

        public bool IsSynced = false;

        public enum OrientationType { Auto, Horizontal, Vertical }
        public OrientationType Orientation = OrientationType.Auto;

        /// <summary>
        /// Calcula la orientación del monitor basado en sus dimensiones
        /// </summary>
        public OrientationType GetCalculatedOrientation()
        {
            if (Orientation != OrientationType.Auto)
                return Orientation;

            if (Bounds.Width > Bounds.Height)
                return OrientationType.Horizontal;
            else if (Bounds.Height > Bounds.Width)
                return OrientationType.Vertical;
            else
                return OrientationType.Horizontal; // Default para cuadrados
        }

        /// <summary>
        /// Retorna la carpeta de imágenes según la orientación calculada
        /// </summary>
        public string GetImageFolder(string baseImagePath)
        {
            var orientation = GetCalculatedOrientation();
            return System.IO.Path.Combine(baseImagePath, 
                orientation == OrientationType.Vertical ? "vertical" : "horizontal");
        }

    }

}
