import { Injectable } from '@nestjs/common';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { ConfigService } from '../config/config.service';

@Injectable()
export class DynamoService {
  private readonly client: DynamoDBDocumentClient;

  constructor(private readonly config: ConfigService) {
    const aws = this.config.getAws();
    const dynamo = new DynamoDBClient({ region: aws.region });
    this.client = DynamoDBDocumentClient.from(dynamo);
  }

  getDocumentClient(): DynamoDBDocumentClient {
    return this.client;
  }
}
