import { Module } from '@nestjs/common';
import { DynamoModule } from '../dynamodb/dynamo.module';
import { S3Module } from '../s3/s3.module';
import { BedrockModule } from '../genai/bedrock.module';
import { DynamoClaimRepository } from '../dynamodb/dynamo.claim.repository';
import { S3NotesRepository } from '../s3/s3.notes.repository';
import { BedrockService } from '../genai/bedrock.service';
import { ClaimsController } from './claims.controller';
import { ClaimsService } from './claims.service';

@Module({
  imports: [DynamoModule, S3Module, BedrockModule],
  controllers: [ClaimsController],
  providers: [
    ClaimsService,
    { provide: 'ClaimRepository', useExisting: DynamoClaimRepository },
    { provide: 'NotesRepository', useExisting: S3NotesRepository },
    { provide: 'SummarizationProvider', useExisting: BedrockService }
  ]
})
export class ClaimsModule {}
