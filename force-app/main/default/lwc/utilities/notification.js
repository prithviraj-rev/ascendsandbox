import { ShowToastEvent } from 'lightning/platformShowToastEvent';

class Notification {
    static TYPE = {
        INFO: 'info',
        ERROR: 'error',
        SUCCESS: 'success',
        WARNING: 'warning'
    };

    static show = (title, message, variant, mode) => {
        if (!mode) {
            if (variant !== Notification.TYPE.SUCCESS) {
                mode = 'sticky';
            } else {
                mode = 'dismissable';
            }
        }

        dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: mode
            })
        );
    };

    static handleError = (error) => {
        this.show(
            'Error',
            (error && ((error.body && error.body.message) || error.message)) || error,
            Notification.TYPE.ERROR
        );
    };
}

export default Notification;