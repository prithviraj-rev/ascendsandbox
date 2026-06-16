import { LightningElement, api } from 'lwc';

export default class RichText extends LightningElement {
    @api fieldValue =" ";
    @api fieldLabel;
    @api required; 
    @api fieldLength;
    @api visibleLines;
    @api recordId;
    @api validity;
    

    @api allowedFormats = [
        'font',
        'size',
        'bold',
        'italic',
        'underline',
        'strike',
        'list',
        'indent',
        'align',
        'link',
        'clean',
        'table',
        'header',
        'color',
        'background',
        'code',
        'code-block',
        'script',
        'blockquote',
        'direction',
    ];

    connectedCallback() {
        this.validity=true;
        document.documentElement.style.setProperty('--rta-visiblelines', (this.visibleLines * 2) + 'em');
    }

    handleChange(event) {
        if((event.target.value).length > this.fieldLength){
            this.validity=false;
            this.errorMessage = "You have exceeded the max length";
        }
       else{
        this.validity = true;
        this.fieldValue = event.target.value;
       }
    }
}