// 最简 diagnostic 函数
module.exports = (req, res) => {
  res.status(200).json({ ok: true, time: Date.now() });
};
