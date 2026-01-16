import { Controller, Get, Param, Post, Body } from '@nestjs/common';
import { ClaimsService } from './claims.service';
import { ClaimResponseDto } from './dto/claim-response.dto';
import { ClaimSummaryResponseDto } from './dto/claim-summary.dto';
import { CreateClaimDto } from './dto/create-claim.dto';

@Controller('claims')
export class ClaimsController {
  constructor(private readonly claims: ClaimsService) {}

  @Get('health')
  health() {
    return { status: 'ok' };
  }

  @Get(':id')
  async getClaim(@Param('id') id: string): Promise<ClaimResponseDto> {
    console.log(`Fetching claim with id: ${id}`);
    return this.claims.getClaimById(id);
  }

  @Post(':id/summarize')
  async summarize(@Param('id') id: string): Promise<ClaimSummaryResponseDto> {
    return this.claims.summarizeClaim(id);
  }

  @Post()
  async createClaim(@Body() createClaimDto: CreateClaimDto): Promise<ClaimResponseDto> {
    return this.claims.createClaim(createClaimDto);
  }
}
