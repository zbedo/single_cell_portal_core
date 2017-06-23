/**
 * Created by yanay on 6/23/17.
 * Code is converted from https://github.com/Neojume/pythonABC
 */

//Sum all the elements of an array
function sum(a){
    var sum = 0;
    a.forEach(function(element){
        sum += element;
    });
    return sum;
}

//Multiply an array by weights array
function array_mult(x, w){
    var ret = new Array(x.length);
    for(i = 0; i < x.length; i++){
        ret[i] = x[i] * w[i];
    }
    return ret
}

//Create an array of "1"s of length n
function ones(n){
    var a = new Array(n);
    for(i = 0; i < n; i++){
        a[i] = 1.0;
    }
    return a

}

//get the weighted mean
function wmean(x, w){
    //Weighted mean returns a number
    //w is an array, so is x
    return sum(array_mult(x , w)) / (sum(w))
}

//get the weighted variance
function wvar(x, w){
    //Weighted variance, returns a number
    //return sum(w * (x - wmean(x, w)) ** 2) / float(sum(w) - 1)
    return sum(array_mult(w, x.map(function(b) {return Math.pow((b - wmean(x,w)), 2) }))) / (sum(w) -1.0)
}

//Normal distribution?
function hnorm(x){
    /*
     Bandwidth estimate assuming f is normal. See paragraph 2.4.2 of
     Bowman and Azzalini[1]_ for details.
     References
     ----------
     .. [1] Applied Smoothing Techniques for Data Analysis: the
     Kernel Approach with S-Plus Illustrations.
     Bowman, A.W. and Azzalini, A. (1997).
     Oxford University Press, Oxford
     */

    //new one array with length x
    var weights = ones(x.length);

    //n = length
    n = sum(weights);

    //always going to be 1d
    var sd = Math.sqrt(wvar(x, weights));
    var b = Math.pow((4.0 / (3.0 * n)), 0.2);
    return sd * b

}

//PDF function from https://github.com/errcw/gaussian/blob/master/lib/gaussian.js
function pdf(x, mean, std) {
    var m = std * Math.sqrt(2 * Math.PI);
    var e = Math.exp(-Math.pow(x - mean, 2) / (2 * Math.pow(std, 2)));
    return e / m;
}

//redundant, but follows python code convention, and has correct mean and variance parameters and constants
function dnorm(x){
    return pdf(x, 0.0, 1.0)
}

//Sheather Jones bandwith selector
//As far as I can tell, this compares SJ vs normal bandwidth to find the best one
function hsj(x){
    /*
     Sheather-Jones bandwidth estimator [1]_.
     References
     ----------
     .. [1] A reliable data-based bandwidth selection method for kernel
     density estimation. Simon J. Sheather and Michael C. Jones.
     Journal of the Royal Statistical Society, Series B. 1991
     */

    var h0 = hnorm(x);
    var v0 = sj(x, h0);
    var hstep = 0;

    if (v0 > 0){
        hstep = 1.1;
    }
    else{
        hstep = 0.9;
    }

    var h1 = h0 * hstep;
    var v1 = sj(x, h1);
    var i = 0;
    while (v1 * v0 > 0 && i < 100){
        h0 = h1;
        v0 = v1;
        h1 = h0 * hstep;
        v1 = sj(x, h1);
        console.log(v1);
        console.log(v0);
        i++;
    }
    return h0 + (h1 - h0) * Math.abs(v0) / (Math.abs(v0) + Math.abs(v1))
}

function phi6(x){
    return (Math.pow(x, 6) - 15 * Math.pow(x, 4) + 45 * Math.pow(x, 2) - 15) * dnorm(x)
}

function phi4(x){
    return (Math.pow(x, 4) - 6 * Math.pow(x, 2) + 3) * dnorm(x)
}

//Create a 2d array by repeating a 1d array n time
function tile(x, n){
    var r = new Array(n);
    for(i = 0; i < n; i++){
        r[i] = x;
    }
    return r
}

//Transposes a matrix-- switches columns and rows
function specialTranspose(x){
    if(x.length < 2 ){
        return x
    }
    else{
        var column_array = [];
        for(r = 0; r < x[0].length; r++){
            var row = [];
            for(c = 0; c < x.length; c++){
                row.push(x[c][r]);
            }
            column_array.push(row);
        }
        return column_array
    }
}

//Dot multiplication method from https://stackoverflow.com/a/27205341
function dot(a, b) {
    var aNumRows = a.length, aNumCols = a[0].length,
        bNumRows = b.length, bNumCols = b[0].length,
        m = new Array(aNumRows);  // initialize array of rows
    for (var r = 0; r < aNumRows; ++r) {
        m[r] = new Array(bNumCols); // initialize the current row
        for (var c = 0; c < bNumCols; ++c) {
            m[r][c] = 0;             // initialize the current cell
            for (var i = 0; i < aNumCols; ++i) {
                m[r][c] += a[r][i] * b[i][c];
            }
        }
    }
    return m;
}

//Custom method to get index of median value
function medianIndex(values) {
    var half = Math.floor(values.length/2.0);
    //if odd
    if((values.length % 2) === 1)
        return half + 0.5;
    //if even
    else
        return half - 0.5;
}

//Custom method to get value of median
function medianValue(values) {
    var half = Math.floor(values.length/2);
    if(values.length % 2 != 0)
        return values[half];
    else
        return (values[half-1] + values[half]) / 2.0;
}

//Custom quartile implementation with linear interpolation for odd length arrays
//Same results as https://docs.scipy.org/doc/numpy-dev/reference/generated/numpy.percentile.html
function quartile(input){
    //Sort the input array
    var arr = input.sort( function(a,b) {return a - b;} );
    //get index and value of median
    var _median_index = medianIndex(arr);
    var median = medianValue(arr);

    //declare variables
    var _firstHalf, _secondHalf;
    //if odd
    if((arr.length % 2) === 1) {
        _firstHalf = arr.slice(0, _median_index);
        _firstHalf.push(median);
        _secondHalf = [median].concat(arr.slice(_median_index +1));
        // find the medians for each split
        var _25percent = medianValue(_firstHalf);
        var _75percent = medianValue(_secondHalf);
        // this will be the upper bounds for each quartile
        return [_25percent, _75percent];
    }
    //if even
    else{

        _firstHalf = arr.slice(0, Math.ceil(_median_index));
        _secondHalf = arr.slice(Math.ceil(_median_index));

        //linear interpolation from numpy
        //This optional parameter specifies the interpolation method to use when the desired quantile lies between two data points i < j:
        //linear: i + (j - i) * fraction, where fraction is the fractional part of the index surrounded by i and j.

        var upperQ_upperVal = _secondHalf[Math.ceil(medianIndex(_secondHalf))];
        var upperQ_lowerVal = _secondHalf[Math.floor(medianIndex(_secondHalf))];
        var lower_upperVal = _firstHalf[Math.ceil(medianIndex(_firstHalf))];
        var lowerQ_lowerVal = _firstHalf[Math.floor(medianIndex(_firstHalf))];

        // find the medians for each split
        var _25percent = lowerQ_lowerVal + (lower_upperVal - lowerQ_lowerVal ) * (0.75);
        var _75percent = upperQ_lowerVal + (upperQ_upperVal - upperQ_lowerVal ) * (0.25);

        // this will be the upper bounds for each quartile
        return [_25percent, _75percent];
    }

}

//Sheather Jones Bandwidth Selection
function sj(x, h){
    /*
     Equation 12 of Sheather and Jones [1]_
     References
     ----------
     .. [1] A reliable data-based bandwidth selection method for kernel
     density estimation. Simon J. Sheather and Michael C. Jones.
     Journal of the Royal Statistical Society, Series B. 1991
     */
    var n = x.length;

    //Returns array of 1's with length n
    var one = [ones(n)];

    //get iqr
    var quartiles = quartile(x);
    var lam = quartiles[1] - quartiles[0];

    //Get a and b-- I don't understand the math
    var a = 0.92 * lam * Math.pow(n, (-1 / 7.0));
    var b = 0.912 * lam * Math.pow(n, (-1 / 9.0));

    //creates array of inputted x arrays of length n
    var W = tile(x, n);

    //switch rows and columns
    var wT = specialTranspose(W);

    //python code W = W - W.T
    //Subtract transposed values from original values-- works because arrays is square (due to tiling)
    var new_W = [];
    for(r = 0; r < W.length; r++){
        var row = [];
        for(c = 0; c < W[0].length; c++){
            row.push(W[r][c] -wT[r][c]);
        }
        new_W.push(row);
    }

    W = new_W;

    //W1 is array of returned values of phi6 (W values divided by b)
    var W1 = [];
    for(r = 0; r < W.length; r++){
        var row = [];
        for(c = 0; c < W[0].length; c++){
            row.push(phi6(W[r][c] / b));
        }
        W1.push(row);
    }
    var oneT = [];
    for(i = 0; i < one[0].length; i++){
        oneT.push([1]);
    }

    //Dot multiply the dot product of one and w1 with one.T
    var tdb = dot(dot(one, W1), oneT);
    //apply this transformation to all of tdb
    tdb = tdb.map(function(k){return -1*k /(n*(n-1)* Math.pow(b,7))});

    //W1 is array of returned values of phi4 (W values divided by a)
    W1 = [];
    for(r = 0; r < W.length; r++){
        var row = [];
        for(c = 0; c < W[0].length; c++){
            row.push(phi4(W[r][c] / a));
        }
        W1.push(row);
    }
    //Dot multiply the dot product of one and w1 with one.T
    var sda = dot(dot(one, W1), oneT);
    sda = sda.map(function(k){return k /(n*(n-1)* Math.pow(a,5))});

    var alpha2 = 1.357 * (Math.pow(Math.abs(sda[0] / tdb[0]) , (1.0 / 7.0))) * Math.pow(h , (5.0 / 7.0));
    //divide w1 by value of alpha2
    W1 = [];
    for(r = 0; r < W.length; r++){
        var row = [];
        for(c = 0; c < W[0].length; c++){
            row.push(phi4(W[r][c] / alpha2));
        }
        W1.push(row);
    }
    //dot multiply the dot product of one and w1 with one.T
    var sdalpha2 = dot(dot(one, W1), oneT);
    //map sdaalpha2 to its self with this transformation
    sdalpha2 = sdalpha2[0]/ (n * (n - 1) * Math.pow(alpha2, 5));
    var k = pdf(0, 0, Math.sqrt(2.0));
    return Math.pow((k / (n * Math.abs(sdalpha2))) , 0.2 ) - h
}
