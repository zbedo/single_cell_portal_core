import React, { Component } from 'react';
import Button from 'react-bootstrap/Button';
import InputGroup from 'react-bootstrap/InputGroup';

const boxStyle = {width: '200px'};

function arraysEqual(a, b) {
  if (a === b) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;

  // If you don't care about the order of the elements inside
  // the array, you should sort both arrays here.
  // Please note that calling sort on an array will modify that array.
  // you might want to clone your array first.

  for (var i = 0; i < a.length; ++i) {
    if (a[i] !== b[i]) return false;
  }
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
      canSave: !arraysEqual(this.state.selection, this.state.savedSelection)
    }));
  }

  handleFilterClick = () => {
    this.setState(() => ({
      selection: this.getCheckedFilterIDs()
    }), () => {
      this.updateCanSaveState();
    });
  };

  handleSaveClick = (event) => {
    const saveButtonClasses = Array.from(event.target.classList);
    
    if (saveButtonClasses.includes('disabled')) return;

    this.setState(() => ({
      savedSelection: this.getCheckedFilterIDs()
    }));
  };

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