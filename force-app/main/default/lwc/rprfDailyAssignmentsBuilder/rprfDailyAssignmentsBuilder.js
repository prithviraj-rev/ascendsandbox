import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { Utilities } from 'c/utilities';

export default class rprfDailyAssignmentsBuilder extends LightningElement 
{
    _recordId;
    showModalSpinner = false;

    @track assignment;

    @api set recordId(value) {
        let newId = (this._recordId != value);
        this._recordId = value;
        if(newId) this.init();
    }

    get recordId() {
        return this._recordId;
    }

    get minDate() {
        return this.assignment?.Start_Date__c;
    }

    get maxDate() {
        return this.assignment?.End_Date__c;
    }

    get startDate() {
        let result = this.assignment?.Start_Date__c;
        if(result && this.endDate) {
            let now = Utilities.getDateFromString(Utilities.getDateISOString(new Date()));
            if(Utilities.getDateFromString(result) < now && Utilities.getDateFromString(this.endDate) >= now) result = Utilities.getDateISOString(now);
        }
        return result;
    }

    get endDate() {
        return this.assignment?.End_Date__c;
    }

    get disableApply() {
        return !this.dataValid();
    }

    init() {
        this.loadAssignment();
    }

    loadAssignment() {
        this.showModalSpinner = true;
        Utilities.Apex.invoke(
            'RPRFDailyAssignmentsBuilderController',
            'getAssignment',
            { assignmentId: this.recordId}
        ).then((data) => {
            this.assignment = data.result;
            this.showModalSpinner = false;
        }).catch((error) => {
            Utilities.Notification.handleError(error);
            this.showModalSpinner = false;
        });
    }

    rebuildDailyAssignments() {
        this.showModalSpinner = true;
        Utilities.Apex.invoke(
            'RPRFDailyAssignmentsBuilderController',
            'rebuildDailyAssignments',
            { 
                assignmentId: this.recordId,
                dailyAssignments: this.template.querySelector('[data-id="rebuild-daily-assignments"]').checked,
                actualHours: this.template.querySelector('[data-id="rebuild-actual"]').checked,
                projectedHours: this.template.querySelector('[data-id="rebuild-projected"]').checked
            }
        ).then((data) => {
            this.handleClose();
        }).catch((error) => {
            this.showModalSpinner = false;
            Utilities.Notification.handleError(error);
        });
    }

    handleApply() {
        this.rebuildDailyAssignments();
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.showModalSpinner = false;
    }
}