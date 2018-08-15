const express = require('express')
const next = require('next')

const Auth = require('auth-14')

const auth = new Auth({
  appId: process.env.AUTH14_APP_ID,
  appSecret: process.env.AUTH14_APP_SECRET,
  providerUrl: 'https://auth14.portchain.com',
  basePath: '/auth'
})


const port = parseInt(process.env.PORT, 10) || 3000
const conf = require('../common/conf')

const withCSS = require('@zeit/next-css')

const app = next(withCSS({
  dev: !conf.isProduction,
  cssModules: true
}))
const handle = app.getRequestHandler()
const migration = require('../common/migration')
const api = require('./api.js')
const monitors = require('./services/monitors.js')

const bodyParser = require('body-parser')

app.prepare()
  .then(migration)
  .then(() => {
    const server = express()
    if (conf.isProduction) {
      server.use((req, res, next) => {
        if (req.headers['x-forwarded-proto'] === 'http') {
          res.writeHead(301, {
            Location: `https://${req.headers.host}${req.url}`
          });
          res.end();
        } else {
          next()
        }
      })
    }
    server.use(auth.serveLogin())
    server.use(bodyParser.json())
    server.use('/api', api(auth))
    
    server.get('*', (req, res) => {
      return handle(req, res)
    })

    server.listen(port, (err) => {
      if (err) throw err
      console.log(`> Ready on http://localhost:${port}`)
      require('../monitor-worker')
    })
  })