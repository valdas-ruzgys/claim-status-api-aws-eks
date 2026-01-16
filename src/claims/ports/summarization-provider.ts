import { Claim } from '../domain/claim';
import { ClaimSummaryResponseDto } from '../dto/claim-summary.dto';

export interface SummarizationProvider {
  summarize(claim: Claim, notes: string[]): Promise<ClaimSummaryResponseDto>;
}
