$( document ).ready(function() 
        {
        //var ProtoBuf = require("protobufjs");
        $( "a" ).click(function( event ) 
            {
            //event.preventDefault();
            //$( this ).hide( "slow" );
            alert( "Thanks for visiting!" );
            });
        $( document ).keydown(function(event) 
            {
            if( event.which == 37 )
            {
                event.preventDefault();
                $("#textField").html("LEFT");
                callServer("LEFT")
            }
            if( event.which == 38 )
            {
                event.preventDefault();
                $("#textField").html("FORWARD");
                callServer("FORWARD")
            }
            if( event.which == 39 )
            {
                event.preventDefault();
                $("#textField").html("RIGHT");
                callServer("RIGHT")
            }
            if( event.which == 40 )
            {
                event.preventDefault();
                $("#textField").html("BACKWARD");
                callServer("BACKWARD")
            }
            });
        });


function callServer(data) 
{
    jQuery.ajax({
        type: "POST",
        url: "/welcome/index",
        data: { "data": data },
        dataType: "json",
        success: function (data, status, jqXHR) {
        // do something
        },

        error: function (jqXHR, status) {
        // error handler
        }
    });
}
