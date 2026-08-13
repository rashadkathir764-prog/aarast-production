type LivePrismaSchema = {
  combinedText: string;
  modelOrder: string[];
};

const { readPrismaSchemaFiles } = require('../../scripts/prisma/schema-files.cjs') as {
  readPrismaSchemaFiles: () => LivePrismaSchema;
};

export function readLivePrismaSchema(): string {
  return readPrismaSchemaFiles().combinedText;
}

export function readLivePrismaModelOrder(): string[] {
  return [...readPrismaSchemaFiles().modelOrder];
}
