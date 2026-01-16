import { Injectable } from '@nestjs/common';

export interface AwsConfig {
  region: string;
  claimsTableName: string;
  notesBucket: string;
  bedrockModelId: string;
  bedrockRegion?: string;
  useMocks: boolean;
}

@Injectable()
export class ConfigService {
  private readonly awsConfig: AwsConfig;

  constructor() {
    this.awsConfig = {
      region: process.env.AWS_REGION || 'us-east-1',
      claimsTableName: process.env.CLAIMS_TABLE_NAME || 'claims-table',
      notesBucket: process.env.NOTES_BUCKET || 'claim-notes-bucket',
      bedrockModelId: process.env.BEDROCK_MODEL_ID || 'amazon.nova-micro-v1:0',
      bedrockRegion: process.env.BEDROCK_REGION,
      useMocks: process.env.USE_MOCKS === 'true'
    };
  }

  getAws(): AwsConfig {
    return this.awsConfig;
  }
}
