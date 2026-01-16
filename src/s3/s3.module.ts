import { Module } from '@nestjs/common';
import { ConfigModule } from '../config/config.module';
import { ConfigService } from '../config/config.service';
import { S3Service } from './s3.service';
import { S3NotesRepository } from './s3.notes.repository';

@Module({
  imports: [ConfigModule],
  providers: [S3Service, S3NotesRepository, ConfigService],
  exports: [S3Service, S3NotesRepository]
})
export class S3Module {}
