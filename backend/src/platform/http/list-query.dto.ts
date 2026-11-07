import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/**
 * Opt-in pagination for list endpoints. Clients that send nothing keep
 * the historical full-list behavior, bounded by DEFAULT_LIST_CAP so one
 * pathological plan cannot serialize an unbounded result set.
 */
export class ListQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  take?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  skip?: number;
}

export const DEFAULT_LIST_CAP = 1000;

/** Prisma findMany args fragment for an optional ListQueryDto. */
export function pageArgs(query?: ListQueryDto): {
  take: number;
  skip?: number;
} {
  return {
    take: query?.take ?? DEFAULT_LIST_CAP,
    ...(query?.skip ? { skip: query.skip } : {}),
  };
}
