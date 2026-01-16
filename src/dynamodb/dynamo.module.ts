import { Module } from '@nestjs/common';
import { ConfigModule } from '../config/config.module';
import { ConfigService } from '../config/config.service';
import { DynamoService } from './dynamo.service';
import { DynamoClaimRepository } from './dynamo.claim.repository';

@Module({
  imports: [ConfigModule],
  providers: [DynamoService, DynamoClaimRepository, ConfigService],
  exports: [DynamoService, DynamoClaimRepository]
})
export class DynamoModule {}
