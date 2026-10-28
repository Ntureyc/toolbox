// Reference ecosystem file for PM2.
//
// Usage:
//   pm2 start ecosystem.config.js
//   pm2 start ecosystem.config.js --only api-service
//
// Production-ready defaults for multi-service environments (API + Web Frontend).

module.exports = {
  apps: [
    {
      name: 'api-service',
      cwd: './backend',
      script: 'bun',
      args: 'run dist/main.js',
      interpreter: 'none',
      instances: 1,
      max_memory_restart: '1G',
      min_uptime: '30s',
      restart_delay: 2000,
      kill_timeout: 10000,
      autorestart: true,
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
    },
    {
      name: 'web-frontend',
      cwd: './frontend',
      script: 'bun',
      args: 'run next start -p 3001',
      interpreter: 'none',
      instances: 1,
      max_memory_restart: '1G',
      min_uptime: '30s',
      restart_delay: 2000,
      kill_timeout: 10000,
      autorestart: true,
      env: {
        NODE_ENV: 'production',
        PORT: 3001,
      },
    },
  ],
};
