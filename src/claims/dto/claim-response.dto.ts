export class ClaimResponseDto {
  readonly id!: string;
  readonly status!: string;
  readonly policyNumber!: string;
  readonly lastUpdated!: string;
  readonly amount!: number;
  readonly customerName!: string;
  readonly adjuster!: string;
}
