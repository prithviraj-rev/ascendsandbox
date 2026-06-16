import { LightningElement, api } from 'lwc';
import { Utilities } from 'c/utilities';

export default class abstractLookup extends LightningElement {
    @api label;
    @api objectName;
    @api valueFieldName = 'Id';
    @api searchFieldName = 'Name';
    @api defaultValue;
    @api valueIconName;  
    @api conditions;
    @api limit = '25';
    @api placeholder = 'Select Value';
    @api searchClass;
    @api variant;

    @api
    clear() {
        this.selectedValueName =  null;
        this.selectedValueId = null;
        this.disaplayValues = false;
        this.fireSelectValue();
    }

    @api
    setValue(valueId, valueName) {
        this.selectedValueId = valueId;
        this.selectedValueName = valueName;
    }

    selectedValueId;
    selectedValueName;

    showSpinner = false;
    disaplayValues = false;
    values = [];
    message = 'Start typing to load data';

    connectedCallback() {
        this.selectedValueName = this.defaultValue;
    }

    handleChange(event) {
        this.selectedValueName = event.target.value;
        this.search(this.selectedValueName);

        if(!this.selectedValueName || this.selectedValueName.length == 0) {
            this.selectedValueId = null;
            this.fireSelectValue();
        }
    }

    handleFocus(event) {
        if(!this.disaplayValues) {
            if(this.values.length > 0) {
                this.disaplayValues = true;
            }else {
                this.search(this.selectedValueName);
            }
        }
    }

    handleBlur(event) {
        this.disaplayValues = false;
    }

    handleKeyUp(event) {
        if(event.keyCode == 27) {
            this.disaplayValues = false;
        }
    }

    handleSelectValue(event) {
        this.selectedValueId = event.target.dataset.key;
        this.selectedValueName = event.target.dataset.name;
        this.disaplayValues = false;
        this.fireSelectValue();
    }

    search(text) {
        this.showSpinner = true;

        Utilities.Apex.invoke(
            'AbstractLookupController', 
            'search', 
            { 
                objectName: this.objectName,
                valueField: this.valueFieldName,
                searchField: this.searchFieldName,
                searchValue: text,
                conditions: this.conditions,
                limitValue: this.limit,
                searchClass: this.searchClass
            }
        ).then((data) => {
            let values = [];
            data.result.forEach(item => {
                values.push({
                    Id: item.value,
                    Name: item.label
                });
            });
            
            this.values = values;
            this.disaplayValues = true;
            this.message = (this.values.length == 0 ? 'No Records Found' : null); 
        })
        .catch(error => Utilities.Notification.handleError(error))
        .finally(() => {
            this.showSpinner = false;
        });
    }

    fireSelectValue() {
        this.dispatchEvent(new CustomEvent("selectvalue", {
            detail: {
                id: this.selectedValueId,
                name: this.selectedValueName
            }
        }));
    }
}