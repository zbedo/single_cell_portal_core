import React, { Component } from 'react';
import Button from 'react-bootstrap/Button';
import InputGroup from 'react-bootstrap/InputGroup';

const boxStyle = {width: '300px'};

/**
 * Are these two sets equal?
 * Adapted for readability from https://stackoverflow.com/a/31129384
 * 
 * @param {Set} setA 
 * @param {Set} setB 
 */
function equalSets(setA, setB) {
  if (setA.size !== setB.size) return false;
  for (var a of setA) if (!setB.has(a)) return false;
  return true;
}

export default class FiltersBox extends Component {
  constructor(props) {
    super(props);
    this.state = {
      canSave: false,
      savedSelection: [],
      selection: [], // Array of selected (e.g. checked) filters
    }
  }

  getCheckedFilterIDs = () => {
    const checkedSelector = `#${this.facetID} input:checked`;
    const checkedFilterIDs = 
      [...document.querySelectorAll(checkedSelector)].map((filter) => {
        return filter.id.split('-').slice(-1);
      });
    return checkedFilterIDs
  }

  updateCanSaveState = () => {
    this.setState(() => ({
      canSave: this.state.selection !== this.state.savedSelection
    }));
  }

  handleFilterClick = () => {
    this.setState(() => ({
      selection: this.getCheckedFilterIDs()
    }));
    this.updateCanSaveState();
  };

  handleSaveClick = (event) => {
    const saveButtonClasses = Array.from(event.target.classList);
    
    if (saveButtonClasses.includes('disabled')) return;

    this.setState(() => ({
      savedSelection: this.getCheckedFilterIDs()
    }));
  };

  // componentDidUpdate(prevProps, prevState, snapshot) {
  // }

  render() {
    const facetName = this.props.facet.name;

    // Systematic, predictable IDs help UX research and UI development.
    //
    // Form of IDs: <general name> <specific name(s)>
    // General name: All lowercase, specified in app code (e.g. 'save-facet', 'filter')
    // Specific name(s): Cased as specified in API (e.g. 'species', 'NCBItaxon9606')
    //
    // UI code concatenates names in the ID.  Names in ID are hyphen-delimited.
    //
    // Examples:
    //   * save-facet-species (for calls-to-action use ID: <action> <component>)
    //   * filter-species-NCBItaxon9606
    this.facetID = `facet-${facetName}`
    const saveID = `save-${this.facetID}`;

    return (
      <div id={this.facetID} style={boxStyle}>
        {this.props.facet.filters.map((d) => {
          const id = `filter-${facetName}-${d.id}`;
          return (
            <li key={id} id={id}>
              <InputGroup.Checkbox
                aria-label="Checkbox"
                name={d.id}
                onClick={this.handleFilterClick}
              />
              <label htmlFor={id}>{d.name}</label>
            </li>
          );
        })}
        <span>Clear</span>
        <Button 
          id={saveID}
          className={this.state.canSave ? 'enabled' : 'disabled'}
          onClick={this.handleSaveClick}
          >
          SAVE
        </Button>
      </div>
    );
  }
}