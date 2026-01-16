import { Injectable, Logger } from '@nestjs/common';
import { BedrockRuntimeClient, InvokeModelCommand } from '@aws-sdk/client-bedrock-runtime';
import { SummarizationProvider } from '../claims/ports/summarization-provider';
import { Claim } from '../claims/domain/claim';
import { ClaimSummaryResponseDto } from '../claims/dto/claim-summary.dto';
import { ConfigService } from '../config/config.service';

@Injectable()
export class BedrockService implements SummarizationProvider {
  private readonly logger = new Logger(BedrockService.name);
  private readonly client: BedrockRuntimeClient;

  constructor(private readonly config: ConfigService) {
    const aws = this.config.getAws();
    this.client = new BedrockRuntimeClient({
      region: aws.bedrockRegion || aws.region
    });
  }

  async summarize(claim: Claim, notes: string[]): Promise<ClaimSummaryResponseDto> {
    const aws = this.config.getAws();
    if (aws.useMocks) {
      return this.mockSummary(claim, notes);
    }

    this.logger.log(`Invoking Bedrock model ${aws.bedrockModelId} for claim ${claim.id}`);

    const prompt = this.buildPrompt(claim, notes);
    const payload = JSON.stringify({
      messages: [
        {
          role: 'user',
          content: [{ text: prompt }]
        }
      ],
      inferenceConfig: {
        maxTokens: 1024,
        temperature: 0.3
      }
    });

    const command = new InvokeModelCommand({
      modelId: aws.bedrockModelId,
      contentType: 'application/json',
      accept: 'application/json',
      body: payload
    });

    const response = await this.client.send(command);
    const body = Buffer.from(response.body as Uint8Array).toString('utf-8');
    const parsed = JSON.parse(body) as {
      output: { message: { content: Array<{ text: string }> } };
    };
    const text = parsed.output?.message?.content?.[0]?.text ?? '';
    return this.parseModelResponse(claim.id, text);
  }

  private buildPrompt(claim: Claim, notes: string[]): string {
    return [
      'You are a claims automation assistant. Produce concise outputs.',
      'Return JSON with keys: overallSummary, customerSummary, adjusterSummary, recommendedNextStep.',
      `Claim: ${JSON.stringify(claim)}`,
      `Notes: ${notes.join('\n')}`,
      'Keep customerSummary plain-language and empathetic.',
      'Keep adjusterSummary action-oriented and specific.',
      'recommendedNextStep must be one actionable sentence.'
    ].join('\n');
  }

  private parseModelResponse(claimId: string, text: string): ClaimSummaryResponseDto {
    try {
      const parsed = JSON.parse(text);
      return {
        claimId,
        overallSummary: parsed.overallSummary ?? text,
        customerSummary: parsed.customerSummary ?? '',
        adjusterSummary: parsed.adjusterSummary ?? '',
        recommendedNextStep: parsed.recommendedNextStep ?? ''
      };
    } catch (error) {
      this.logger.warn(`Model response was not JSON; returning raw text; ${error}`);

      return {
        claimId,
        overallSummary: text,
        customerSummary: text,
        adjusterSummary: text,
        recommendedNextStep: 'Review generated summary and determine next action.'
      };
    }
  }

  private mockSummary(claim: Claim, notes: string[]): ClaimSummaryResponseDto {
    const noteSnippet = notes.slice(0, 2).join(' ');
    return {
      claimId: claim.id,
      overallSummary: `Claim ${claim.id} is ${claim.status}. ${noteSnippet}`,
      customerSummary: `We are working on your claim ${claim.id}. Status: ${claim.status}.`,
      adjusterSummary: `Focus on documentation for claim ${claim.id}; latest note: ${noteSnippet}`,
      recommendedNextStep: 'Verify documents and contact customer within 1 business day.'
    };
  }
}
