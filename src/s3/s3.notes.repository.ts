import { Injectable, Logger } from '@nestjs/common';
import { GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { ConfigService } from '../config/config.service';
import { NotesRepository } from '../claims/ports/notes-repository';
import { S3Service } from './s3.service';
import { readFile } from 'fs/promises';

@Injectable()
export class S3NotesRepository implements NotesRepository {
  private readonly logger = new Logger(S3NotesRepository.name);

  constructor(
    private readonly s3: S3Service,
    private readonly config: ConfigService
  ) {}

  async getNotesForClaim(claimId: string): Promise<string[]> {
    const aws = this.config.getAws();
    if (aws.useMocks) {
      return this.readFromMocks(claimId);
    }

    const client = this.s3.getClient();
    const key = `${claimId}.json`;
    const command = new GetObjectCommand({
      Bucket: aws.notesBucket,
      Key: key
    });
    const response = await client.send(command);
    const body = await response.Body?.transformToString('utf-8');
    if (!body) return [];
    const parsed = JSON.parse(body) as { notes: string[] };
    return parsed.notes;
  }

  async saveNotesForClaim(claimId: string, notes: string[]): Promise<void> {
    const aws = this.config.getAws();
    if (aws.useMocks) {
      this.logger.log(`Mock mode: would save notes for ${claimId}`);
      return;
    }

    const client = this.s3.getClient();
    const key = `${claimId}.json`;
    const body = JSON.stringify({ notes });

    const command = new PutObjectCommand({
      Bucket: aws.notesBucket,
      Key: key,
      Body: body,
      ContentType: 'application/json'
    });

    await client.send(command);
    this.logger.log(`Saved notes for claim ${claimId}`);
  }

  private async readFromMocks(claimId: string): Promise<string[]> {
    try {
      const raw = await readFile('./mocks/notes.json', 'utf-8');
      const notes: Record<string, string[]> = JSON.parse(raw);
      return notes[claimId] ?? [];
    } catch (error) {
      this.logger.error('Failed to read mock notes', error as Error);
      return [];
    }
  }
}
