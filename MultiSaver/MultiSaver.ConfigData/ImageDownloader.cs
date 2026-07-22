using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace MultiSaver.ConfigData
{
    /// <summary>
    /// Sincroniza imágenes desde Wasabi S3 y las organiza por orientación
    /// </summary>
    public class ImageDownloader
    {
        public string WasabiAccessKey { get; set; }
        public string WasabiSecretKey { get; set; }
        public string WasabiBucket { get; set; }
        public string WasabiRegion { get; set; }
        public string WasabiEndpoint { get; set; }
        public string LocalImageDir { get; set; }

        private string S3Host => $"{WasabiBucket}.{WasabiEndpoint}";

        public ImageDownloader()
        {
            WasabiRegion = "us-east-1";
            WasabiEndpoint = "s3.us-east-1.wasabisys.com";
        }

        /// <summary>
        /// Sincroniza imágenes desde Wasabi S3 al directorio local
        /// </summary>
        public bool SyncFromWasabi()
        {
            if (string.IsNullOrEmpty(WasabiAccessKey) || string.IsNullOrEmpty(WasabiSecretKey) ||
                string.IsNullOrEmpty(WasabiBucket) || string.IsNullOrEmpty(LocalImageDir))
            {
                System.Diagnostics.Debug.WriteLine("ERROR: Credenciales de Wasabi incompletas");
                return false;
            }

            try
            {
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
                Directory.CreateDirectory(LocalImageDir);

                var remoteObjects = ListBucketObjects();
                if (remoteObjects == null || remoteObjects.Count == 0)
                {
                    System.Diagnostics.Debug.WriteLine("WARNING: No objects found in Wasabi bucket");
                    return true;
                }

                System.Diagnostics.Debug.WriteLine($"Found {remoteObjects.Count} objects in bucket");

                // Descargar/sincronizar archivos
                foreach (var obj in remoteObjects)
                {
                    if (obj.Key.EndsWith("/"))
                        continue;

                    string localPath = Path.Combine(LocalImageDir, obj.Key.Replace("/", "\\"));
                    string localDir = Path.GetDirectoryName(localPath);

                    Directory.CreateDirectory(localDir);

                    bool shouldDownload = true;
                    if (File.Exists(localPath))
                    {
                        var fileInfo = new FileInfo(localPath);
                        if (fileInfo.Length == obj.Size)
                        {
                            shouldDownload = false;
                        }
                    }

                    if (shouldDownload)
                    {
                        System.Diagnostics.Debug.WriteLine($"Downloading {obj.Key}...");
                        if (!DownloadFile(obj.Key, localPath))
                        {
                            System.Diagnostics.Debug.WriteLine($"ERROR: Failed to download {obj.Key}");
                            return false;
                        }
                    }
                }

                // Limpiar archivos locales que no existen remotamente
                var remoteKeys = remoteObjects.Select(o => o.Key.Replace("/", "\\")).ToList();
                RemoveDeletedFiles(remoteKeys);

                // Organizar imágenes por orientación
                ImageHelper.OrganizeImagesIntoOrientationFolders(LocalImageDir);

                System.Diagnostics.Debug.WriteLine("S3 sync completed successfully");
                return true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"ERROR: S3 sync failed: {ex.Message}");
                return false;
            }
        }

        private List<S3Object> ListBucketObjects()
        {
            var objects = new List<S3Object>();
            string continuationToken = null;

            do
            {
                string queryString = "list-type=2";
                if (!string.IsNullOrEmpty(continuationToken))
                {
                    queryString += "&continuation-token=" + Uri.EscapeDataString(continuationToken);
                }

                var responseXml = InvokeS3Get("/", queryString);
                if (responseXml == null)
                    return null;

                try
                {
                    XDocument doc = XDocument.Parse(responseXml);
                    XNamespace ns = "http://s3.amazonaws.com/doc/2006-03-01/";

                    var contents = doc.Descendants(ns + "Contents");
                    foreach (var item in contents)
                    {
                        var keyElement = item.Element(ns + "Key");
                        var sizeElement = item.Element(ns + "Size");

                        if (keyElement != null && sizeElement != null)
                        {
                            objects.Add(new S3Object
                            {
                                Key = keyElement.Value,
                                Size = long.Parse(sizeElement.Value)
                            });
                        }
                    }

                    var isTruncated = doc.Element(ns + "ListBucketResult")?.Element(ns + "IsTruncated")?.Value;
                    var nextToken = doc.Element(ns + "ListBucketResult")?.Element(ns + "NextContinuationToken")?.Value;

                    if (isTruncated == "true" && !string.IsNullOrEmpty(nextToken))
                    {
                        continuationToken = nextToken;
                    }
                    else
                    {
                        break;
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"ERROR parsing S3 response: {ex.Message}");
                    return null;
                }
            } while (true);

            return objects;
        }

        private bool DownloadFile(string s3Key, string localPath)
        {
            try
            {
                string encodedKey = Uri.EscapeDataString(s3Key).Replace("%2F", "/");
                byte[] fileData = InvokeS3GetBinary("/" + encodedKey, "");
                
                if (fileData == null || fileData.Length == 0)
                    return false;

                File.WriteAllBytes(localPath, fileData);
                return true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"ERROR downloading file: {ex.Message}");
                return false;
            }
        }

        private void RemoveDeletedFiles(List<string> remoteKeys)
        {
            try
            {
                var localFiles = Directory.GetFiles(LocalImageDir, "*.*", SearchOption.AllDirectories);
                foreach (var localFile in localFiles)
                {
                    string relPath = localFile.Substring(LocalImageDir.Length + 1);
                    if (!remoteKeys.Contains(relPath))
                    {
                        try
                        {
                            File.Delete(localFile);
                            System.Diagnostics.Debug.WriteLine($"Deleted: {relPath}");
                        }
                        catch { }
                    }
                }
            }
            catch { }
        }

        private string InvokeS3Get(string uri, string queryString)
        {
            try
            {
                var now = DateTime.UtcNow;
                string amzDate = now.ToString("yyyyMMddTHHmmssZ");
                string dateStamp = now.ToString("yyyyMMdd");
                string payloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

                string auth = GetS3AuthHeader("GET", uri, queryString, S3Host, payloadHash, amzDate, dateStamp);

                string url = $"https://{S3Host}{uri}";
                if (!string.IsNullOrEmpty(queryString))
                    url += "?" + queryString;

                using (WebClient client = new WebClient())
                {
                    client.Headers.Add("x-amz-content-sha256", payloadHash);
                    client.Headers.Add("x-amz-date", amzDate);
                    client.Headers.Add("Authorization", auth);

                    return client.DownloadString(url);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"ERROR in S3 GET: {ex.Message}");
                return null;
            }
        }

        private byte[] InvokeS3GetBinary(string uri, string queryString)
        {
            try
            {
                var now = DateTime.UtcNow;
                string amzDate = now.ToString("yyyyMMddTHHmmssZ");
                string dateStamp = now.ToString("yyyyMMdd");
                string payloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

                string auth = GetS3AuthHeader("GET", uri, queryString, S3Host, payloadHash, amzDate, dateStamp);

                string url = $"https://{S3Host}{uri}";
                if (!string.IsNullOrEmpty(queryString))
                    url += "?" + queryString;

                using (WebClient client = new WebClient())
                {
                    client.Headers.Add("x-amz-content-sha256", payloadHash);
                    client.Headers.Add("x-amz-date", amzDate);
                    client.Headers.Add("Authorization", auth);

                    return client.DownloadData(url);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"ERROR downloading binary: {ex.Message}");
                return null;
            }
        }

        private string GetS3AuthHeader(string method, string uri, string queryString, string host, 
            string payloadHash, string amzDate, string dateStamp)
        {
            string canonicalHeaders = $"host:{host}\nx-amz-content-sha256:{payloadHash}\nx-amz-date:{amzDate}\n";
            string signedHeaders = "host;x-amz-content-sha256;x-amz-date";
            string canonicalRequest = $"{method}\n{uri}\n{queryString}\n{canonicalHeaders}\n{signedHeaders}\n{payloadHash}";

            string credentialScope = $"{dateStamp}/{WasabiRegion}/s3/aws4_request";

            using (SHA256 sha = SHA256.Create())
            {
                byte[] crHash = sha.ComputeHash(Encoding.UTF8.GetBytes(canonicalRequest));
                string crHashStr = BitConverter.ToString(crHash).Replace("-", "").ToLower();

                string stringToSign = $"AWS4-HMAC-SHA256\n{amzDate}\n{credentialScope}\n{crHashStr}";

                using (HMACSHA256 hmac = new HMACSHA256(Encoding.UTF8.GetBytes($"AWS4{WasabiSecretKey}")))
                {
                    byte[] kDate = hmac.ComputeHash(Encoding.UTF8.GetBytes(dateStamp));
                    hmac.Key = kDate;
                    byte[] kRegion = hmac.ComputeHash(Encoding.UTF8.GetBytes(WasabiRegion));
                    hmac.Key = kRegion;
                    byte[] kService = hmac.ComputeHash(Encoding.UTF8.GetBytes("s3"));
                    hmac.Key = kService;
                    byte[] kSigning = hmac.ComputeHash(Encoding.UTF8.GetBytes("aws4_request"));
                    hmac.Key = kSigning;
                    byte[] sig = hmac.ComputeHash(Encoding.UTF8.GetBytes(stringToSign));
                    string sigStr = BitConverter.ToString(sig).Replace("-", "").ToLower();

                    return $"AWS4-HMAC-SHA256 Credential={WasabiAccessKey}/{credentialScope}, SignedHeaders={signedHeaders}, Signature={sigStr}";
                }
            }
        }

        private class S3Object
        {
            public string Key { get; set; }
            public long Size { get; set; }
        }
    }
}
