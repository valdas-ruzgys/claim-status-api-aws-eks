import { Module } from '@nestjs/common';
import { ConfigModule } from './config/config.module';
import { DynamoModule } from './dynamodb/dynamo.module';
import { S3Module } from './s3/s3.module';
import { BedrockModule } from './genai/bedrock.module';
import { ClaimsModule } from './claims/claims.module';

@Module({
  imports: [ConfigModule, DynamoModule, S3Module, BedrockModule, ClaimsModule]
})
export class AppModule {}
