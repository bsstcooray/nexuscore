import React from 'react';
import { Mascot } from 'page-mascot';

/**
 * NexusCore Bottom-Right Mascot Component
 * 
 * Embeds the animated Koala Mascot from page-mascot package
 * with 8-direction cursor tracking and click reactions.
 */
export function MascotCorner() {
  return (
    <div 
      className="page-mascot-wrapper" 
      style={{ position: 'fixed', bottom: 20, right: 20, zIndex: 990 }}
      aria-label="NexusCore Koala Mascot"
    >
      <Mascot
        directions="/mascots/koala-directions.webp"
        reactions="/mascots/koala-reactions.webp"
      />
    </div>
  );
}

export { Mascot };
export default MascotCorner;
