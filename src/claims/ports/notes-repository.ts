export interface NotesRepository {
  getNotesForClaim(claimId: string): Promise<string[]>;
}
