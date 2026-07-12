'use strict';

const { rmSync } = require('node:fs');
const { basename, dirname, resolve } = require('node:path');

const backendRoot = resolve(__dirname, '..');
const outputDirectory = resolve(backendRoot, 'dist');

if (
  dirname(outputDirectory) !== backendRoot ||
  basename(outputDirectory) !== 'dist'
) {
  throw new Error('Refusing to clean an unexpected build output directory');
}

rmSync(outputDirectory, { recursive: true, force: true });
