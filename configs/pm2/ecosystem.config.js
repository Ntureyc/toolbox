// Reference ecosystem file.
//
//   pm2 start ecosystem.config.js --name my-app
//
// The names here match the apps that run on the boxes, so a deploy
// script can rely on them.

module.exports = {
  apps: [
    {
      name: 'business-koro-api',
      cwd: '/home/ntureyc/business-koro/backend',
      script: 'bun',
      args: 'run dist/main.js',
      interpreter: 'none',
      max_memory_restart: '1G',
      min_uptime: '30s',
      restart_delay: 2000,
      kill_timeout: 10000,
      autorestart: true,
      env: {
        NODE_ENV: 'production',
      },
    },
    {
      name: 'business-koro-web',
      cwd: '/home/ntureyc/business-koro/frontend',
      script: 'bun',
      args: 'run next start -p 3012',
      interpreter: 'none',
      max_memory_restart: '1G',
      min_uptime: '30s',
      restart_delay: 2000,
      kill_timeout: 10000,
      autorestart: true,
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};
