import { LightningElement, track, api } from 'lwc';

export default class CaseItem extends LightningElement {
    @api caseRecord={};
    @api viewFields=[];

    get cardTitle(){
        return this.caseRecord.CaseNumber + ': ' + this.caseRecord.Status;
    }
    
    get ownerColorStyle(){
        return "color-bg color-"+this.caseRecord.ownerSequence;
    }

    get priorityIcon(){
        return (this.caseRecord.Priority=="High")?"utility:arrowup":"";
    }
    get highPriority(){
        return (this.caseRecord.Priority=="High");
    }
    get isReviewed(){
        return (this.caseRecord.reviewed=='Yes');
    }
    get isClosed(){
        console.log(this.caseRecord.isClosed, 'CLOSED');
        return (this.caseRecord.isClosed==true);
    }
    get closedOrCanceled(){
        if (this.caseRecord.isClosed==true) {console.log(this.caseRecord.Status=="Closed"?"closed":"canceled");}
        
        return (this.caseRecord.isClosed==true)?(this.caseRecord.Status=="Closed"?"closed":"canceled"):"";
    }
    
    get shortReview(){
        return this.caseRecord.shortReview.replace(/\n/g,"<br/>");
    }

    handleSelection(event){
        console.log('Selected case ', this.caseRecord.CaseNumber);
        const selectedEvent = new CustomEvent("selected", { detail: this.caseRecord.caseId });
        this.dispatchEvent(selectedEvent);
    }

    connectedCallback(){
        console.log(this.caseRecord.Status, JSON.stringify(this.caseRecord));
    }
}