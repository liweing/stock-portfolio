// Vercel Serverless Function: 天天基金代理（绕过 CORS）
// Web 端访问 /api/fund?code=000071 → 这里转发到 fundgz.1234567.com.cn
module.exports = async function handler(req, res) {
  const { code, rt } = req.query;

  if (!code || !/^\d{6}$/.test(code)) {
    res.status(400).json({ error: 'Invalid fund code' });
    return;
  }

  try {
    const timestamp = rt || Date.now();
    const response = await fetch(
      `https://fundgz.1234567.com.cn/js/${code}.js?rt=${timestamp}`,
      {
        headers: {
          'User-Agent': 'Mozilla/5.0',
          Referer: 'https://fund.eastmoney.com/',
        },
      }
    );

    const text = await response.text();

    // 天天基金对不存在的基金返回 HTML 404 页面，检测并转为干净的 404
    if (!text.startsWith('jsonpgz(')) {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.status(404).json({
        error: 'Fund not found',
        code,
        hint: '该基金代码在天天基金系统未找到，可能是场内 ETF/LOF 或已摘牌基金',
      });
      return;
    }

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
    res.setHeader('Cache-Control', 's-maxage=30');
    res.status(200).send(text);
  } catch (err) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.status(500).json({ error: err.message });
  }
};
