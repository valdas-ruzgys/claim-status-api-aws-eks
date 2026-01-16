import { Module } from '@nestjs/common';
import { ConfigModule } from '../config/config.module';
import { ConfigService } from '../config/config.service';
import { BedrockService } from './bedrock.service';

@Module({
  imports: [ConfigModule],
  providers: [BedrockService, ConfigService],
  exports: [BedrockService]
})
export class BedrockModule {}
