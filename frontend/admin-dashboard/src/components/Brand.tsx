import { Boxes } from 'lucide-react';

export function Brand() {
  return (
    <div className="brand" aria-label="SmartDrop Admin">
      <div className="brand-mark"><Boxes size={19} strokeWidth={2.1} /></div>
      <div>
        <div className="brand-name">SmartDrop</div>
        <div className="brand-caption">Smart locker delivery operations</div>
      </div>
    </div>
  );
}
