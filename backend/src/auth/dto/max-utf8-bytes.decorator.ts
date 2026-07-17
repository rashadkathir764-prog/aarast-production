import {
  registerDecorator,
  ValidationArguments,
  ValidationOptions,
} from "class-validator";

/**
 * bcrypt only processes the first 72 bytes. Reject longer inputs before
 * hashing so two visibly different passwords can never authenticate as one.
 */
export function MaxUtf8Bytes(
  maximumBytes: number,
  validationOptions?: ValidationOptions,
): PropertyDecorator {
  return (target: object, propertyName: string | symbol) => {
    registerDecorator({
      name: "maxUtf8Bytes",
      target: target.constructor,
      propertyName: propertyName.toString(),
      constraints: [maximumBytes],
      options: validationOptions,
      validator: {
        validate(value: unknown): boolean {
          return (
            typeof value === "string" &&
            Buffer.byteLength(value, "utf8") <= maximumBytes
          );
        },
        defaultMessage(args: ValidationArguments): string {
          return `${args.property} must not exceed ${maximumBytes} UTF-8 bytes`;
        },
      },
    });
  };
}
