import { Injectable, Logger } from '@nestjs/common';
import { GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { readFile } from 'fs/promises';
import { ClaimRepository } from '../claims/ports/claim-repository';
import { Claim } from '../claims/domain/claim';
import { DynamoService } from './dynamo.service';
import { ConfigService } from '../config/config.service';

@Injectable()
export class DynamoClaimRepository implements ClaimRepository {
  private readonly logger = new Logger(DynamoClaimRepository.name);

  constructor(
    private readonly dynamo: DynamoService,
    private readonly config: ConfigService
  ) {}

  async getById(id: string): Promise<Claim | null> {
    const aws = this.config.getAws();

    if (aws.useMocks) {
      return this.readFromMocks(id);
    }

    const client = this.dynamo.getDocumentClient();
    const command = new GetCommand({
      TableName: aws.claimsTableName,
      Key: { id }
    });
    const result = await client.send(command);
    return (result.Item as Claim) ?? null;
  }

  private async readFromMocks(id: string): Promise<Claim | null> {
    try {
      const raw = await readFile('./mocks/claims.json', 'utf-8');
      const claims: Claim[] = JSON.parse(raw);

      return claims.find((c) => c.id === id) ?? null;
    } catch (error) {
      this.logger.error('Failed to read mock claims file', error as Error);
      return null;
    }
  }

  async create(claim: Claim): Promise<Claim> {
    const aws = this.config.getAws();
    if (aws.useMocks) {
      throw new Error('Creating claims in mocks is not supported');
    }

    const client = this.dynamo.getDocumentClient();
    const command = new PutCommand({
      TableName: aws.claimsTableName,
      Item: claim
    });
    await client.send(command);

    return claim;
  }
}
