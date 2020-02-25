import { useState } from 'react';

/**
 * Custom hook for boxes that have "APPLY" and "Clear" for one or more
 * filter lists, e.g. FiltersBox or FacetsAccordionBox
 */
export default function useApplyAndClear() {

  const [canApply, setCanApply] = useState(false);
  const [showClear, setShowClear] = useState(false);
  const [appliedSelection, setAppliedSelection] = useState([]);
  const [selection, setSelection] = useState([]);

  return {
    canApply, setCanApply,
    showClear, setShowClear,
    appliedSelection, setAppliedSelection,
    selection, setSelection
  };
}
