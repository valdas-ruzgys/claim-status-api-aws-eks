export interface NotesRepository {
  getNotesForClaim(claimId: string): Promise<string[]>;
  saveNotesForClaim(claimId: string, notes: string[]): Promise<void>;
}
