import { Injectable } from '@nestjs/common';
import { S3Client } from '@aws-sdk/client-s3';
import { ConfigService } from '../config/config.service';

@Injectable()
export class S3Service {
  private readonly client: S3Client;

  constructor(private readonly config: ConfigService) {
    const aws = this.config.getAws();
    this.client = new S3Client({ region: aws.region });
  }

  getClient(): S3Client {
    return this.client;
  }
}
