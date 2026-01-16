import { IsString, IsNotEmpty } from 'class-validator';

export class ClaimSummaryRequestDto {
  @IsString()
  @IsNotEmpty()
  readonly id!: string;
}

export class ClaimSummaryResponseDto {
  readonly claimId!: string;
  readonly overallSummary!: string;
  readonly customerSummary!: string;
  readonly adjusterSummary!: string;
  readonly recommendedNextStep!: string;
}
