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

/**
 * Prisma findMany args fragment for an optional ListQueryDto. [cap] is the
 * list's size when no page is asked: a list with a bound of its own (a plan's
 * guests, D99) passes it, so a client reading it whole gets it whole.
 */
export function pageArgs(
  query?: ListQueryDto,
  cap = DEFAULT_LIST_CAP,
): {
  take: number;
  skip?: number;
} {
  return {
    take: query?.take ?? cap,
    ...(query?.skip ? { skip: query.skip } : {}),
  };
}
