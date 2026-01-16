export interface Claim {
  id: string;
  status: 'OPEN' | 'PENDING_INFO' | 'CLOSED' | 'DENIED';
  policyNumber: string;
  lastUpdated: string;
  amount: number;
  customerName: string;
  adjuster: string;
}
