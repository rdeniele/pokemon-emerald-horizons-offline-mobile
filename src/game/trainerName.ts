/** Public names deliberately cannot contain email addresses or control characters. */
export const TRAINER_NAME_PATTERN = /^[A-Za-z0-9_]{3,20}$/;
export function validTrainerName(value: string): boolean {
  return value===value.trim()&&TRAINER_NAME_PATTERN.test(value);
}
export function publicTrainerName(value: unknown): string {
  return typeof value === "string" && validTrainerName(value.trim()) ? value.trim() : "Trainer";
}
