$(document).ready(function() {
    // show the alert
    setTimeout(function() {
        $(".alert").alert('close');
    }, 5000);

    $('[data-toggle="tooltip"]').tooltip();


    $(document).on("mouseenter mouseleave", "#calendario .anime-item .plot", function (e) {
        if (e.type === "mouseenter") {
            $(this).css("overflow-y","scroll");
        } else {
            $(this).css("overflow-y","hidden");
            $(this).scrollTop(0);
        }
    });

});

function confirmAccountDelete(user_id) {
    $('#confirm-delete form').attr('action', 'https://' + window.location.hostname + "/user/" + user_id)
}



