import { Claim } from '../domain/claim';

export interface ClaimRepository {
  getById(id: string): Promise<Claim | null>;
  create(claim: Claim): Promise<Claim>;
}
