const express = require('express');
const compression = require('compression');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

// Активираме агресивна Gzip компресия на сървъра
app.use(compression({
    level: 9, // Максимална компресия
    threshold: 0 // Компресирай всичко, независимо от размера
}));

// Прокси филтър
app.use('/', createProxyMiddleware({
    target: 'http://target-url.com', // Това ще се променя динамично от заявката
    router: (req) => {
        const url = req.url.startsWith('http') ? req.url : 'http://' + req.headers.host;
        return url;
    },
    changeOrigin: true,
    onProxyRes: function (proxyRes, req, res) {
        // Тук сървърът казва на браузъра, че данните са компресирани
        proxyRes.headers['Content-Encoding'] = 'gzip';
    }
}));

const PORT = process.env.PORT || 8080;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server-side compression proxy running on port ${PORT}`);
});