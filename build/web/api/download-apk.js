// Vercel Serverless Function: APK 下载代理
// 通过 fetch 内部静态文件并强制 Content-Disposition: attachment 触发浏览器下载
module.exports = async function handler(req, res) {
  const apkUrl =
    'https://stockportfolio.company/downloads/app-release.apk';

  try {
    const response = await fetch(apkUrl);
    if (!response.ok) {
      res.status(response.status).json({ error: 'APK not found' });
      return;
    }

    const buffer = Buffer.from(await response.arrayBuffer());

    res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    res.setHeader(
      'Content-Disposition',
      'attachment; filename="stock-portfolio.apk"'
    );
    res.setHeader('Content-Length', buffer.length);
    res.setHeader('Cache-Control', 'public, max-age=300, s-maxage=300');
    res.status(200).send(buffer);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
