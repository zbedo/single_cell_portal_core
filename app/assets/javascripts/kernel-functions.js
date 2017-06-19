/**
 * Created by yanay on 6/13/17.
 * Kernel Formulas from https://github.com/jasondavies/science.js
 * Kernel formulas from https://gist.github.com/mbostock/4341954
 */


//Kernel Density Estimator takes a kernel function and array of 1d data and returns a function that can create an array of density probabilty
//estimates
function kernelDensityEstimator(kernel, X) {
    return function(V) {
        return X.map(function(x) {
            return [x, d3.mean(V, function(v) { return kernel(x - v); })];
        });
    };
}

/* Rule of thumb bandwidth selector from :
*  https://en.wikipedia.org/wiki/Kernel_density_estimation#Bandwidth_selection
*/
function rotBandwidth(X){
    return 1.06 * ss.standardDeviation(X) * Math.pow(X.length, -0.2)
}

/* Kernels are functions that transform a data point, used in Kernel Density Estimator
*  Kernel Formulas from https://github.com/jasondavies/science.js
*  Kernel formulas from https://gist.github.com/mbostock/4341954
*/

function kernelEpanechnikov(k) {
    return function(v) {
        return Math.abs(v /= k) <= 1 ? 0.75 * (1 - v * v) / k : 0;
    };
}
function kernelUniform(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) return .5 / k;
        return 0;
    };
}
function kernelTriangular(k) {
    return function (v) {
        if (Math.abs(v /= k) <= 1) return (1 - Math.abs(v)) / k;
        return 0;
    };
}
function kernelQuartic(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) {
            var tmp = 1 - v * v;
            return (15 / 16) * tmp * tmp / k;
        }
        return 0;
    };
}
function kernelTriweight(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) {
            var tmp = 1 - v * v;
            return (35 / 32) * tmp * tmp * tmp / k;
        }
        return 0;
    };
}

function kernelGaussian(k) {
    return function(v) {
        return 1 / Math.sqrt(2 * Math.PI) * Math.exp(-.5 * v * v) / k;
    };
}
function kernelCosine(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) return Math.PI / 4 * Math.cos(Math.PI / 2 * v) / k;
        return 0;
    };
}

//The following kernel functions were written by Yanay
function kernelTricube(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) {
            var tmp = (1 - Math.pow(Math.abs(v), 3));
            return (70 / 81) * tmp * tmp * tmp / k;
        }
        return 0;
    };
}
function kernelLogistic(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) return 1 / (Math.pow(Math.E, v) + 2 + Math.pow(Math.E, -v))  / k;
        return 0;
    };
}
function kernelSigmoid(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) return 2 / (Math.PI * (Math.pow(Math.E, v) + Math.pow(Math.E, -v)))  / k;
        return 0;
    };
}
function kernelSilverman(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) return 0.5 *  Math.pow(Math.E, -1 * (Math.abs(v)) / Math.sqrt(2.0)) * Math.sin((Math.abs(v) / Math.sqrt(2.0)) + Math.PI/4.0)  / k;
        return 0;
    };
}

//Random sign returns either 1 or -1 randomly in order to flip points over the x axis randomly when creating x values
function randomSign(){
    var v = Math.random();
    return v >= .5 ? 1 : -1
}

//Returns the largest number in an array
function getMaxOfArray(numArray) {
    return Math.max.apply(null, numArray);
}

//Returns the smallest number in an array
function getMinOfArray(numArray) {
    return Math.min.apply(null, numArray);
}

/* This function checks if a number is an outlier based on the simple definition of an outlier found at:
*  http://www.itl.nist.gov/div898/handbook/prc/section1/prc16.htm
*  lower inner fence: Q1 - 1.5*IQ
*  upper inner fence: Q3 + 1.5*IQ
*/
function isOutlier(x, l, u){
    var con = (u-l) * 1.5;
    return x >= u ? ((x - con) > u) : ((x + con) < l);

}

//This function splits an array into two arrays- its outliers and its normal data
function cutOutliers(arr, l, u){
    var outliers = [];
    var small_arr = arr;

    for(var i = arr.length; i >= 0; i--){
        if(isOutlier(arr[i], l, u)){
            outliers.push(arr[i]);
            small_arr.splice(i, 1);
        }
    }
    return [outliers, small_arr]

}


/*
 *For Javascript only file for testing, this is the array of colors from colorbrewer
 var colorBrewerSet = ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00", "#a65628", "#f781bf", "#999999",
 "#66c2a5", "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854", "#ffd92f", "#e5c494", "#b3b3b3", "#8dd3c7",
 "#bebada", "#fb8072", "#80b1d3", "#fdb462", "#b3de69", "#fccde5", "#d9d9d9", "#bc80bd", "#ccebc5", "#ffed6f"];*/

/*
 * this works faster than simple statistics for <10000 entries for unknown reasons, but simple statistics is being used instead

 function quartile(arr){
 // find the median as you did
 arr.sort( function(a,b) {return a - b;} );
 var _median = medianIndex(arr);
 var _firstHalf, _secondHalf;
 // split the data by the median
 //if odd
 if((arr.length % 2) === 1) {
 _firstHalf = arr.slice(0, _median -1);
 _secondHalf = arr.slice(_median +1);
 }
 //if even
 else
 {
 _firstHalf = arr.slice(0, _median);
 _secondHalf = arr.slice(_median + 0.5);
 }

 // find the medians for each split
 var _25percent = median(_firstHalf);
 var _75percent = median(_secondHalf);
 // this will be the upper bounds for each quartile
 return [_25percent, _75percent];
 }


 function medianIndex(values) {

 values.sort( function(a,b) {return a - b;} );

 var half = Math.floor(values.length/2.0);

 //if odd
 if((values.length % 2) === 1)
 return half + 0.5;
 //if even
 else
 return half - 0.5;
 }

 function median(values) {

 values.sort( function(a,b) {return a - b;} );

 var half = Math.floor(values.length/2);

 if(values.length % 2)
 return values[half];
 else
 return (values[half-1] + values[half]) / 2.0;
 }

 */

function createTracesAndLayout(arr){
    //dataA is the array of plotly traces that is returned by this method
    dataA = [];

    //group is the current violin plot number being formatted
    var group = 0;

    //this is the default layout set up, before additional x axis are added on
    var layout = {
        height: 800,
        yaxis: {
            zeroline: true,
            showline: true

        },
        margin: {
            pad: 10

        },
        //x axis may be more than |1| math wise so commented out
        // xaxis: {range: [-1, 1]},
        width: 1000};

    //This is the maximum horizontal value of every violin plot, used later to re-range the plots and provide padding horizontally
    var x_vals_maxs = [];

    //Iterate through every violin plot
    //fullData is the array of information about one violin plot in format [name, array of data points, kernel type, bandwidth]
    arr.forEach(function(fullData) {
        //Set the name of the group of traces (Violin Plot)
        var group_name = fullData[0];
        //Set the bandwidth
        bandwidth = typeof fullData[3] !== 'undefined' ? fullData[3] : rotBandwidth(fullData[1]);

        //Set the Kernel based on passed parameters
        //Potential Kernel Options: "sil", "sig", "log","uni", "gau", "tri","triw", "qua", "tric","cos", "epa"
        //var current_kernel = kernelSilverman(bandwidth);
        var kernel_name = fullData[2];
        switch (kernel_name) {
            case "sil":
                var current_kernel = kernelSilverman(bandwidth);
                break;
            case "sig":
                var current_kernel = kernelSigmoid(bandwidth);
                break;
            case "log":
                var current_kernel = kernelLogistic(bandwidth);
                break;
            case "uni":
                var current_kernel = kernelUniform(bandwidth);
                break;
            case "gau":
                var current_kernel = kernelGaussian(bandwidth);
                break;
            case "tri":
                var current_kernel = kernelTriangular(bandwidth);
                break;
            case "triw":
                var current_kernel = kernelTriweight(bandwidth);
                break;
            case "qua":
                var current_kernel = kernelQuartic(bandwidth);
                break;
            case "tric":
                var current_kernel = kernelTricube(bandwidth);
                break;
            case "cos":
                var current_kernel = kernelCosine(bandwidth);
                break;
            case "epa":
                var current_kernel = kernelEpanechnikov(bandwidth);
                break;
            default:
                //Epanechnikov is the most used kernel
                var current_kernel = kernelEpanechnikov(bandwidth);
        }

        //We only need the array of points now
        var pointData = fullData[1];

        //Set the color of the trace to a color brewer constan.
        // If there are more than 20 traces the colors start from the beginning again
        var color = colorBrewerSet[group % 20];

        //Calculate the median value and sort the data in ascending order
        var median_v = ss.median(pointData);
        pointData.sort( function(a,b) {return a - b;} );

        //Calculate the upper and lower Quartiles
        var lower_q = ss.quantile(pointData, 0.25);
        var upper_q = ss.quantile(pointData, 0.75);

        //Set the X axis for this violin plot
        var axis = 'x' + (group + 1).toString();

        //Separate outliers from the data
        var out_array = cutOutliers(pointData, lower_q, upper_q);

        //Set new arrays to the outliers and normal data
        var noOutData = out_array[1];
        var outliers = out_array[0];

        //Create the Kernel Estimating Function
        var kdeT = kernelDensityEstimator(current_kernel, noOutData);

        //Get the array of density values
        var kde_array = kdeT(noOutData);


        //Format the Array for use in traces, and mirror it to mirror half of violin plot across Y axis
        var x_vals = [];
        var y_vals = [];
        var mir_x_vals = [];

        kde_array.forEach(function(element) {
            x_val = element[1];
            mir_x_val = - element[1];
            y_val = element[0];
            x_vals.push(x_val);
            y_vals.push(y_val);
            mir_x_vals.push(mir_x_val);
        });


        //Trace1 is the right hand (positive value) Violin Plot
        var trace1 = {
            x: x_vals,
            y: y_vals,
            fill: 'tonextx',
            fillcolor: color,
            //Identify the plot as master to all other plots in the legend
            legendgroup: 'Group: ' + group.toString(),
            layer: 'below',
            //Edge of Violin Line
            line: {
                color: 'rgb(0,0,0)',
                shape: 'spline',
                width: 2
            },
            mode: 'lines',
            //Set plot name
            name: group_name,
            xaxis: axis,
            opacity: 0.05
        };

        //Trace2 is the mirrored version of Trace1 across the Y axis
        var trace2 = {
            x: mir_x_vals,
            y: y_vals,
            fill: 'tonextx',
            fillcolor: color,
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            layer: 'below',
            //Edge of Violin Line
            line: {
                color: 'rgb(0,0,0)',
                shape: 'spline',
                width: 2
            },
            mode: 'lines',
            xaxis: axis,
            opacity: 0.05
        };

        //Get the max value of x for ranging the horizontal size of plot
        var x_vals_max = getMaxOfArray(x_vals);

        //For the sideline trace, create an array of equal x values for plotting line mode scatter plot
        var x_array_offset = new Array(noOutData.length);
        x_array_offset.fill(x_vals_max * -1.2);

        //Trace10 is the blue line trace to the right. Currently this feature is unwanted
        var trace10 = {
            y: noOutData,
            x: x_array_offset,
            type: 'scatter',
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            marker: {
                color: 'rgb(31, 119, 180)',
                symbol: 'line-ew-open'
            },
            mode: 'markers',
            xaxis: axis


        };

        //This code is for generating random x values for the jitter scatter plot trace
        var x_array_random = [];
        //This code is to restrain the jitter to the shape of the violin plot, which is currently unwanted
        /*for (var i=0; i< element.length; i++) {
         c = x_vals[i];
         d = randomSign();
         //The reason for this math is to place the dot randomly within the bounds of the violin plot but offset it away from the
         //center line as to not obscure the median or quartiles
         x_array_random.push((c * d * Math.random() * 0.75 ) + (d * 0.1 * c))
         }*/

        //Generate unconstrained random x values
        for (var i=0; i< noOutData.length; i++) {
            //The values are actually constrained to the domain of the graph
            c = x_vals_max;
            //Calling random sign means that the jitter points will appear on either side of the Y axis
            d = randomSign();
            //The reason for this math is to place the dot randomly within the bounds of the violin plot but offset it away from the
            //center line as to not obscure the median or quartiles
            x_array_random.push((d * c * Math.random() * 0.75 ) + (d * 0.1 * c))
        }

        //Trace3 is the jitter scatter plot. X values are generated randomly, and Y values represent non outlier points
        var trace3 = {
            y: noOutData,
            x: x_array_random,
            type: 'scatter',
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            marker: {
                color: 'rgb(0, 0, 0)',
                size: 3
            },
            mode: 'markers',
            xaxis: axis


        };

        //Create random X values for outlier points
        var outliers_x = new Array();
        for (var i=0; i< outliers.length; i++) {
            //The values are actually constrained to the domain of the graph
            c = x_vals_max;
            //Calling random sign means that the jitter points will appear on either side of the Y axis
            d = randomSign();
            //The reason for this math is to place the dot randomly within the bounds of the violin plot but offset it away from the
            //center line as to not obscure the median or quartiles
            //The range of X values for outliers is much smaller than non outliers
            outliers_x.push((d * c * Math.random() * 0.1 ))
        }

        //Trace 7 is the outliers scatter plot, plots outliers as 'X's
        var trace7 = {
            y: outliers,
            x: outliers_x,
            type: 'scatter',
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            marker: {
                color: 'rgb(40, 40, 255)',
                symbol: 'x'
            },
            mode: 'markers',
            xaxis: axis


        };

        //Shape Traces

        //Trace 4 is the center line of the violin plot
        var trace4 = {
            //Center the line in the middle of the plot
            x: [0, 0],
            //Y values are set to the minimum and maximum of the y data, to draw a line between the top and bottom of the violin
            y: [getMinOfArray(noOutData), getMaxOfArray(noOutData)],
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            line: {
                color: 'rgb(200, 200, 200)',
                width: 1
            },
            mode: 'lines',
            name: '',
            type: 'scatter',
            xaxis: axis

        };

        //Trace5 is the quartile line
        var trace5 = {
            x: [0, 0],
            xaxis: axis,
            y: [lower_q, upper_q],
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            hoverinfo: 'text',
            line: {
                color: 'rgb(0,0,0)',
                width: 4
            },
            mode: 'lines',
            text: ['lower-quartile: ' + lower_q.toString(), 'upper-quartile: ' + upper_q.toString()],
            type: 'scatter'
        };

        //Trace6 is the median white square
        var trace6 = {
            x: [0],
            xaxis: axis,
            y: [median_v],
            hoverinfo: 'text',
            showlegend: false,
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            marker: {
                color: 'rgb(255,255,255)',
                symbol: 'square'
            },
            mode: 'markers',
            text: ['median: ' + median_v.toString()],
            type: 'scatter'
        };

        //Trace 8 is the capping line on top of violin plot
        var trace8 = {
            x: [-x_vals[x_vals.length-1], x_vals[x_vals.length-1]],
            xaxis: axis,
            y: [y_vals[x_vals.length-1], y_vals[x_vals.length-1] ],
            showlegend: false,
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            line: {
                color: 'rgb(0,0,0)',
                width: 2
            },
            mode: 'lines'
        };

        //Trace9 is the capping line on the bottom of the violin plot
        var trace9 = {
            x: [-x_vals[0], x_vals[0]],
            xaxis: axis,
            y: [y_vals[0], y_vals[0] ],
            showlegend: false,
            //Slave the plot to Trace1 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            line: {
                color: 'rgb(0,0,0)',
                width: 2
            },
            mode: 'lines'
        };

        //Append the traces to the larger group of traces
        dataA.push([trace1, trace2, trace3, trace4, trace5, trace6, trace7, trace8, trace9]);

        //Increment group number and record maximum horizontal value
        group++;
        x_vals_maxs.push(x_vals_max);

    });

    //Domain step is used as a reference for parsing the width of the div among th Plotly plots
    //As the number of plots increases, each plots share of the width decreases proportionally
    var domain_step = 1.0/arr.length;

    //Create the X Axes
    for(var i = 1;i <= group; i++){

        var x_axis = {
            //Defailt X Axis settings
            showticklabels: false,
            margin: {
                r: 20

            },
            zeroline: false,
            showgrid: false,

            //Set the positioning and relative width of the plot. Proportional to the number of plots being plotted overall
            domain: [(domain_step * (i-1)), (domain_step * (i))],
            //Set the width of the plot to slighlty more than that of the violin, to give the appearance of padding
            range: [-1.1* x_vals_maxs[i-1], 1.1* x_vals_maxs[i-1]]
        };

        //Append the new X axis to the layout and name it appropriately by number
        var current_axis = 'xaxis' + i.toString();
        layout[current_axis] = x_axis

    }

    //Return the Plotly data array and Plotly layout array
    return [dataA, layout]

}
