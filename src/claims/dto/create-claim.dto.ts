import { IsString, IsNumber, IsEnum, IsOptional, IsArray } from 'class-validator';

export class CreateClaimDto {
  @IsOptional()
  @IsString()
  readonly id?: string;

  @IsOptional()
  @IsEnum(['OPEN', 'PENDING_INFO', 'CLOSED', 'DENIED'])
  readonly status?: 'OPEN' | 'PENDING_INFO' | 'CLOSED' | 'DENIED';

  @IsString()
  readonly policyNumber!: string;

  @IsOptional()
  @IsString()
  readonly lastUpdated?: string;

  @IsNumber()
  readonly amount!: number;

  @IsString()
  readonly customerName!: string;

  @IsString()
  readonly adjuster!: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  readonly notes?: string[];
}
