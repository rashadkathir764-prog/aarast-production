// Runs the hourly reminder scan once against the scale database and times it.
const req = require('module').createRequire('/home/user/aarast-production/backend/package.json');
req('reflect-metadata');
const path = '/home/user/aarast-production/backend/dist';
const { NestFactory } = req('@nestjs/core');
const { AppModule } = require(path + '/app.module');
const { NotificationsService } = require(path + '/notifications/notifications.service');
(async () => {
  const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error', 'warn'] });
  const svc = app.get(NotificationsService);
  const t0 = Date.now();
  try {
    const n = await svc.generateDueNotifications();
    console.log(`reminder scan: created=${n} in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
  } catch (e) {
    console.log(`reminder scan FAILED after ${((Date.now() - t0) / 1000).toFixed(1)}s: ${e.constructor.name} ${e.code ?? ''} ${String(e.message).slice(0, 300)}`);
  }
  await app.close();
  process.exit(0);
})();
