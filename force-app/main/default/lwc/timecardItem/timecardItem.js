import { LightningElement, api } from 'lwc';

export default class TimecardItem extends LightningElement {
    @api tc;
    hasChanges;//track changes and show unsaved icon.
    

    isReviewed;
    isClosed;
    highPriority;
    name;
    closedOrCanceled="closed";
    description;

    get isNew(){
        return (this.tc && this.tc.tcid=="new");
    }

    get isDiff(){
        //console.log('diffCheck: ', this.tc.diff);
        return (this.tc && this.tc.tcid!="new" && this.tc.diff==true);
    }

    get priorityIcon(){
        return (this.highPriority==true)?"utility:arrowup":"";
    }

    get title(){
        let title = '';
        if (this.tc.timecard ){
            let hrs = parseFloat(this.tc.hours);
            title = hrs + ": ";
            if (this.tc.projectName){
                title += this.tc.projectName;
            } else {
                title +="project not set";
            }
        }
        return title;
    }
    get desc(){

        return (this.tc && this.tc.description)?this.tc.description.replace(/\n/g,"<br/>"):"";
    }
    connectedCallback(){
        //console.log("timecardItem", JSON.stringify(this.tc));

    }

    handleEntryClick(event){
        //console.log('Entry click from entry', JSON.stringify(this.tc));
        this.dispatchEvent(new CustomEvent('entryclick',{detail:this.tc.tcid}));
    }
}