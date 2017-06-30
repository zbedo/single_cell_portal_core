/**
 * Created by yanay on 6/13/17.
 * Kernel Formulas from https://github.com/jasondavies/science.js
 * Kernel formulas from https://gist.github.com/mbostock/4341954
 */


//Kernel Density Estimator takes a kernel function and array of 1d data and returns a function that can create an array of density probabilty
function kernelDensityEstimator(kernel, X) {
    return function(V) {
        return X.map(function(x) {
            return [x, d3.mean(V, function(v) { return kernel(x - v); })];
        });
    };
}

/* Advanced Rule of thumb bandwidth selector from :
*  https://en.wikipedia.org/wiki/Kernel_density_estimation#Bandwidth_selection
*  and https://stat.ethz.ch/R-manual/R-devel/library/stats/html/bandwidth.html
*/

function nrd0(X){
    var iqr = ss.quantile(X, 0.75) - ss.quantile(X, 0.25);
    var iqrM = iqr /1.34;
    var std = ss.sampleStandardDeviation(X);
    var min = std < iqrM ? std : iqrM;
    if(min === 0){
        min = std
    }
    if(min === 0){
        min = Math.abs(X[1])
    }
    if(min === 0){
        min = 1.0
    }
    return 0.9 * min * Math.pow(X.length, -0.2)
}

/* Kernels are functions that transform a data point, used in Kernel Density Estimator
*  Kernel Formulas from https://github.com/jasondavies/science.js
*  Kernel formulas from https://gist.github.com/mbostock/4341954
*/

function kernelEpanechnikov(k) {
    return function(v) {
        return Math.abs(v /= k) <= 1 ? 0.75 * (1 - (Math.pow(v, 2))) / k : 0;
    };
}
function kernelUniform(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) return 0.5 / k;
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

function kernelCosine(k) {
    return function(v) {
        if (Math.abs(v /= k) <= 1) return Math.PI / 4 * Math.cos(Math.PI / 2 * v) / k;
        return 0;
    };
}

//The following kernel functions were written by Yanay

//This gives the best results-- It represents essentially exact copies of R default violin plots
function kernelGaussian(k) {
    return function(v) {
        //get normal distribution probability of v in sample with mean of 0 and standard deviation of k (the bandwidth)
        return pdf(v, 0,k);
    };
}

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

//Resolution is the number of equally spaced y values that will have their density, x, calculated
function genRes(length, min, max){
    //Resolution = larger of 512 or length of data
    var resolution = length > 512 ? length : 512;
    //Calculate equal spacing of y Points and push all to array
    var ratio = (max-min) /(resolution -1.0);
    var res_points =[];

    for(var i = 0.0; i < resolution; i++){
        res_points.push((ratio * i) + min);
    }
    return res_points
}

//This is the master function that creates all the plotly traces.
//Takes an array of arrays and returns the data array of traces and the layout variable
function createTracesAndLayout(arr, title){
    //dataA is the array of plotly traces that is returned by this method
    dataA = [];

    //group is the current violin plot number being formatted
    var group = 0;
    //this is the default layout set up, before additional x axis are added on
    var layout = {
        hovermode: 'closest',
        title: title,
        height: 1000,
        font: plotlyLabelFont,
        yaxis: {
            zeroline: true,
            showline: true,
            title: 'Expression'

        },
        margin: {
            pad: 10,
            b: 100

        }
    };

    //This is the maximum horizontal value of every violin plot, used later to re-range the plots and provide padding horizontally
    //TRemnant of multiple X axis
    var x_vals_maxs = [];

    //Hardcoding a maximum value to scale all violin plots. Essentially this value shouldn't matter as long as it is >0
    var scale_max = 1.0;

    //Setting up single X axis
    var name_array = [];
    //Center Lines is for the xAxis labels to make sure they line up with appropriate trace
    var center_lines = [];
    //Inital offset is 0 because it's the first trace
    var x_offset = 0;

    //Iterate through every violin plot
    //fullData is the array of information about one violin plot in format [name, array of data points, kernel type, bandwidth]
    arr.forEach(function(fullData) {
        //Set the name of the group of traces (Violin Plot), is the cluster name

        var group_name = fullData[0];
        name_array.push(group_name);

        //Set the bandwidth
        var bandwidth_type = fullData[3];
        switch (bandwidth_type) {
            case "nrd0":
                var bandwidth = nrd0(fullData[1]);
                var modifiers = true;
                break;
            case "sjste":
                var bandwidth = hsj(fullData[1]);
                break;
            default:
                //Gaussian is the best kernel
                var bandwidth = nrd0(fullData[1]);
        }

        //Set the Kernel based on passed parameters. Only kernels currently in use are epa and gau, which is default
        //Potential Kernel Options: "sil", "sig", "log","uni", "gau", "tri","triw", "qua", "tric","cos", "epa"

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
                bandwidth = bandwidth * Math.sqrt(3.0);
                var current_kernel = kernelUniform(bandwidth);
                break;
            case "gau":
                var current_kernel = kernelGaussian(bandwidth);
                break;
            case "tri":
                bandwidth = bandwidth * Math.sqrt(6.0);
                var current_kernel = kernelTriangular(bandwidth);
                break;
            case "triw":
                var current_kernel = kernelTriweight(bandwidth);
                break;
            case "qua":
                bandwidth = bandwidth * Math.sqrt(7.0);
                var current_kernel = kernelQuartic(bandwidth);
                break;
            case "tric":
                var current_kernel = kernelTricube(bandwidth);
                break;
            case "cos":
                bandwidth = bandwidth/(Math.sqrt((1.0/3.0) - (2/(Math.PI * Math.PI))));
                var current_kernel = kernelCosine(bandwidth);
                break;
            case "epa":
                bandwidth = bandwidth * Math.sqrt(5.0);
                var current_kernel = kernelEpanechnikov(bandwidth);
                break;
            default:
                //Gaussian is the best kernel
                var current_kernel = kernelGaussian(bandwidth);
        }

        //We only need the array of points now
        var pointData = fullData[1];

        //Set the color of the trace to a color brewer constant
        // If there are more than 20 traces the colors start from the beginning again
        var color = colorBrewerSet[group % 20];

        //Calculate the median value and sort the data in ascending order
        var median_v = ss.median(pointData);
        pointData.sort( function(a,b) {return a - b;} );

        //Calculate the upper and lower Quartiles
        var lower_q = ss.quantile(pointData, 0.25);
        var upper_q = ss.quantile(pointData, 0.75);

        var axis = 'x';
        /*Separate outliers from the data
        * This is not desired behavior but I'm leaving it in in case it is wanted in future
        * No outlier data is actually useful, as it is used for jitter points
        */
        var out_array = cutOutliers(pointData.slice(), lower_q, upper_q);

        //Set new arrays to the outliers and normal data-- normal data is supposed to include outliers
        //so it goes back to original full point data
        var noOutData = out_array[1];
        var outliers = out_array[0];

        //Get the array of density values
        var min = getMinOfArray(pointData);
        var max = getMaxOfArray(pointData);

        //Resolution is the number of equally spaced y values that will have their density, x, calculated
        //Resolution = larger of 512 or length of data
        var res_points = genRes(pointData.length, min, max);

        //Create the Kernel Estimating Function
        var kde = kernelDensityEstimator(current_kernel, res_points);
        var kde_array = kde(pointData);

        //Format the Array for use in traces, and mirror it to mirror half of violin plot across Y axis
        var x_vals = [];
        var y_vals = [];
        var mir_x_vals = [];

        kde_array.forEach(function(element) {
            //right x values
            x_val = element[1];
            //Left side of traces = -1 * right side x values
            mir_x_val = - element[1];
            //kde conveniently gives us the y values again, although its the same as res points its best to double check
            //by returning the same values
            y_val = element[0];

            //push to arrays
            x_vals.push(x_val);
            y_vals.push(y_val);
            mir_x_vals.push(mir_x_val);
        });

        //Get the max value of x for ranging the horizontal size of plot. Some kernels give negative numbers for unknown reason.
        //Therefore, getting the largest abs value number and setting it to max
        var x_vals_max = getMaxOfArray(x_vals);
        var x_vals_min = getMinOfArray(x_vals);
        x_vals_max = Math.abs(x_vals_max) > Math.abs(x_vals_min) ? x_vals_max : x_vals_min;

        //scaling all violin plots. Scale factor means max width = scale_max
        var scale_factor = scale_max / x_vals_max ;

        //Reset maximum
        x_vals_max = x_vals_max * scale_factor;

        //If heavy zero data, scale factor may be 1/0 or infinity, so reduce it to irrelevant
        if(scale_factor === Infinity){
            scale_factor = scale_max;
        }

        //Reduce x's and mirrored x's to max width scaled
        x_vals = x_vals.map(function(x) {return x * scale_factor});
        mir_x_vals = mir_x_vals.map(function(x) {return x * scale_factor});
        //offset x values.
        //The offset value each time is equal to the maximum width of the plot + a constant 1.
        //The offset tells you where the left side (mirror trace) should extend to maximally
        x_vals = x_vals.map(function(x) {return x + x_offset + x_vals_max});

        //offset mirrored x vals
        mir_x_vals = mir_x_vals.map(function(x) {return x + x_offset + x_vals_max});

        //Trace1 is the right hand (positive value) Violin Plot
        var trace1 = {
            x: x_vals,
            y: y_vals,
            //color brewer color
            fillcolor: color,
            //Slave the plot to Trace2 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            //Edge of Violin Line
            line: {
                color: 'rgb(0,0,0)',
                shape: 'spline',
                width: 1
            },
            mode: 'lines',
            //Set plot name
            name: group_name,
            hoverinfo: 'none',
            xaxis: axis
            //opacity: 0.05
        };

        //Trace2 is the mirrored version of Trace1 across the Y axis
        var trace2 = {
            x: mir_x_vals,
            y: y_vals,
            fill: 'tonextx',
            fillcolor: color,
            name: group_name,
            //Identify the plot as master to all other plots in the legend
            legendgroup: 'Group: ' + group.toString(),

            //Edge of Violin Line
            line: {
                color: 'rgb(0,0,0)',
                shape: 'spline',
                width: 1
            },
            mode: 'lines',
            hoverinfo: 'none',
            xaxis: axis
        };

        //This code is for generating random x values for the jitter scatter plot trace
        var x_array_random = [];

        //Generate unconstrained random x values
        for (i=0; i < noOutData.length; i++) {
            //The values are actually constrained to the domain of the trace
            c = scale_max;
            //Calling random sign means that the jitter points will appear on either side of the Y axis, randomly
            d = randomSign();
            //The reason for this math is to place the dot randomly within the bounds of the violin plot but offset it away from the
            //center line as to not obscure the median or quartiles
            x_array_random.push((d * c * Math.random() * 0.75 ) + (d * 0.1 * c) + x_offset + scale_max)
        }

        //Trace3 is the jitter scatter plot. X values are generated randomly, and Y values represent non outlier points
        //Generate overlay text in format 'Cluster X Jitter: Value'
        var jitter_text = [];
        for(i = 0; i < noOutData.length; i++){
            jitter_text.push(group_name + ' Jitter: ' + noOutData[i])
        }

        var trace3 = {
            //Y values are data minus outliers
            y: noOutData,
            //X values have no significance, so are random
            x: x_array_random,
            type: 'scatter',
            //Slave the plot to Trace2 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            marker: {
                color: 'rgb(0, 0, 0)',
                size: 3
            },
            mode: 'markers',
            xaxis: axis,
            hoverinfo: 'text',
            text: jitter_text
        };

        //Create random X values for outlier points
        var outliers_x = [];
        for (var i=0; i< outliers.length; i++) {
            //The values are actually constrained to the domain of the graph
            c = scale_max;
            //Calling random sign means that the outlier points will appear on either side of the Y axis
            d = randomSign();
            /*The reason for this math is to place the dot randomly within the bounds of the violin plot but offset it away from the
            * center line as to not obscure the median or quartiles
            * The range of X values for outliers is much smaller than non outliers
            */
            outliers_x.push((d * c * Math.random() * 0.1 ) + x_offset + scale_max)
        }

        //Trace 7 is the outliers scatter plot, plots outliers as 'X's
        //Generate overlay text in format 'Cluster X Outlier: Value'
        var outlier_text = [];
        for(i = 0; i < outliers.length; i++){
            outlier_text.push(group_name + ' Outlier: ' + outliers[i])
        }

        var trace7 = {
            y: outliers,
            x: outliers_x,
            type: 'scatter',
            text: outlier_text,
            //Slave the plot to Trace2 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            marker: {
                //color: color,
                color: 'rgb(0,0,0)',
                symbol: 'x'
            },
            mode: 'markers',
            xaxis: axis,
            hoverinfo: 'text'
        };

        //Shape Traces
        //Trace 4 is the center line of the violin plot
        var trace4 = {
            /*Center the line in the middle of the plot
            * because x offset tells you where the leftmost boundary of the trace should be, you must add the maximum value,
            * aka the width of the mirrored left trace to it to get the cent of the trace
            */
            x: [x_offset + x_vals_max, x_offset + x_vals_max],
            //Y values are set to the minimum and maximum of the y data, to draw a line between the top and bottom of the violin
            y: [getMinOfArray(pointData), getMaxOfArray(pointData)],
            //Slave the plot to Trace2 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            showlegend: false,
            line: {
                color: 'rgb(200, 200, 200)',
                width: 1
            },
            mode: 'lines',
            name: 'Center ' + group_name,
            type: 'scatter',
            xaxis: axis

        };
        //record middle of trace for labels
        center_lines.push(x_offset + scale_max);

        //Trace5 is the quartile line
        var trace5 = {
            x: [x_offset + x_vals_max, x_offset + x_vals_max],
            xaxis: axis,
            y: [lower_q, upper_q],
            //Slave the plot to Trace2 and hide it from the legend
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
            x: [x_offset + x_vals_max],
            xaxis: axis,
            y: [median_v],
            hoverinfo: 'text',
            showlegend: false,
            //Slave the plot to Trace2 and hide it from the legend
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
            x: [mir_x_vals[x_vals.length-1], x_vals[x_vals.length-1]],
            xaxis: axis,
            y: [y_vals[x_vals.length-1], y_vals[x_vals.length-1] ],
            showlegend: false,
            //Slave the plot to Trace2 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            line: {
                color: 'rgb(0,0,0)',
                width: 1
            },
            mode: 'lines',
            hoverinfo: 'none'
        };

        //Trace9 is the capping line on the bottom of the violin plot
        var trace9 = {
            x: [mir_x_vals[0], x_vals[0]],
            xaxis: axis,
            y: [y_vals[0], y_vals[0] ],
            showlegend: false,
            //Slave the plot to Trace2 and hide it from the legend
            legendgroup: 'Group: ' + group.toString(),
            line: {
                color: 'rgb(0,0,0)',
                width: 1
            },
            mode: 'lines',
            hoverinfo: 'none'
        };

        /* Append the traces to the larger group of traces
        * Alternate order is for overlaing
        * Order is [right violin, left violin, jitter points, center line, quartile line, median white square, top capping line, bottom capping line, outliers]
        */
        dataA.push([trace1, trace2, trace3, trace4, trace5, trace6, trace8, trace9, trace7]);

        //Increment group number and record maximum horizontal value for offset
        group++;
        x_vals_maxs.push(x_vals_max);
        //The offset value each time is equal to the maximum width of the plot + a constant 1. The offset tells you where the left side (mirror trace) should extend to maximally

        x_offset = x_offset + (2.2 * scale_max);
    });

    var x_axis = {
        showticklabels: true,

        zeroline: false,
        ticktext: name_array,
        showgrid: false,
        tickvals: center_lines

    };
    //Return the Plotly data array and Plotly layout array
    layout["xaxis"] = x_axis;
    return [dataA, layout]

}
