import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { ClaimRepository } from './ports/claim-repository';
import { NotesRepository } from './ports/notes-repository';
import { SummarizationProvider } from './ports/summarization-provider';
import { ClaimResponseDto } from './dto/claim-response.dto';
import { ClaimSummaryResponseDto } from './dto/claim-summary.dto';
import { Claim } from './domain/claim';

@Injectable()
export class ClaimsService {
  constructor(
    @Inject('ClaimRepository') private readonly claims: ClaimRepository,
    @Inject('NotesRepository') private readonly notes: NotesRepository,
    @Inject('SummarizationProvider')
    private readonly summarizer: SummarizationProvider
  ) {}

  async getClaimById(id: string): Promise<ClaimResponseDto> {
    const claim = await this.claims.getById(id);
    if (!claim) {
      throw new NotFoundException(`Claim ${id} not found`);
    }
    return { ...claim };
  }

  async summarizeClaim(id: string): Promise<ClaimSummaryResponseDto> {
    const claim = await this.claims.getById(id);
    if (!claim) {
      throw new NotFoundException(`Claim ${id} not found`);
    }
    const notes = await this.notes.getNotesForClaim(id);
    return this.summarizer.summarize(claim, notes);
  }

  async createClaim(claimData: Partial<Claim> & { notes?: string[] }): Promise<ClaimResponseDto> {
    const claim: Claim = {
      id: claimData.id || `CLM-${Date.now()}`,
      status: claimData.status || 'OPEN',
      policyNumber: claimData.policyNumber || '',
      lastUpdated: claimData.lastUpdated || new Date().toISOString(),
      amount: claimData.amount || 0,
      customerName: claimData.customerName || '',
      adjuster: claimData.adjuster || ''
    };
    const created = await this.claims.create(claim);

    // Save notes if provided
    if (claimData.notes && claimData.notes.length > 0) {
      await this.notes.saveNotesForClaim(created.id, claimData.notes);
    }

    return { ...created };
  }
}
