import assert from 'node:assert/strict';
import { test } from 'node:test';
import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate, ValidationError } from 'class-validator';
import { CreateGuestDto } from '../src/guests/dto/create-guest.dto';
import { ImportLocalGuestDto } from '../src/onboarding/dto/import-local-guest.dto';
import { ImportLocalPlanDto } from '../src/onboarding/dto/import-local-plan.dto';
import { ImportLocalTaskDto } from '../src/onboarding/dto/import-local-task.dto';
import { CreateTaskDto } from '../src/tasks/dto/create-task.dto';

type NormalizedError = {
  property: string;
  constraints: Record<string, string> | undefined;
  children: NormalizedError[];
};

const normalizeErrors = (errors: ValidationError[]): NormalizedError[] => errors.map((error) => ({
  property: error.property,
  constraints: error.constraints,
  children: normalizeErrors(error.children || []),
}));

const validationErrors = async <T extends object>(Dto: new () => T, payload: Record<string, unknown>) =>
  normalizeErrors(await validate(plainToInstance(Dto, payload)));

test('local task DTO preserves validation errors for the declared payload cases', async () => {
  for (const payload of [
    { title: 'مهمة' },
    { title: '', status: 'INVALID', priority: 'INVALID' },
    { title: 'مهمة', responsibleSource: 'deviceContact' },
    { title: 'مهمة', responsibleSource: 'unknown' },
  ]) {
    assert.deepEqual(
      await validationErrors(ImportLocalTaskDto, payload),
      await validationErrors(CreateTaskDto, payload),
    );
  }
});

test('local guest DTO preserves validation errors for the declared payload cases', async () => {
  for (const payload of [
    { name: 'ضيف' },
    { name: '', seatsCount: 0, companionsCount: -1 },
    { name: 'ضيف', seatsCount: 20, companionsCount: 20 },
    { name: 'ضيف', phone: '1'.repeat(41), side: 'INVALID' },
  ]) {
    assert.deepEqual(
      await validationErrors(ImportLocalGuestDto, payload),
      await validationErrors(CreateGuestDto, payload),
    );
  }
});

test('local plan creates local nested task and guest DTO instances', () => {
  const value = plainToInstance(ImportLocalPlanDto, {
    clientMigrationId: 'local-import-contract',
    tasks: [{ title: 'مهمة' }],
    guests: [{ name: 'ضيف' }],
  });
  assert.ok(value.tasks?.[0] instanceof ImportLocalTaskDto);
  assert.ok(value.guests?.[0] instanceof ImportLocalGuestDto);
});
