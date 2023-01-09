#ifndef PZ_SPARSE_H
#define PZ_SPARSE_H

#include "Parameters.h"

// A specialized implementation of PZsparse
// so that more variables can be tracked
// qddae
// qdae
// qde
// sinqe
// cosqe
// k
// 6 * 7 = 42 variables in total
// qddae (maximum degree 1 bit (1))
// qdae  (maximum degree 1 bit (1))
// qde   (maximum degree 1 bit (1))
// sinqe (maximum degree 2 bits (3))
// cosqe (maximum degree 2 bits (3))
// k     (maximum degree 2 bits (3))
// 9 * 7 = 63 digits stored in one uint64_t

const uint64_t MOVE_BIT_INC[NUM_FACTORS * 6] = {2, 2, 2, 2, 2, 2, 2,
                                                2, 2, 2, 2, 2, 2, 2,
                                                2, 2, 2, 2, 2, 2, 2,
                                                1, 1, 1, 1, 1, 1, 1,
                                                1, 1, 1, 1, 1, 1, 1,
                                                1, 1, 1, 1, 1, 1, 1};

const uint64_t DEGREE_MASK[NUM_FACTORS * 6] = {3, 3, 3, 3, 3, 3, 3,
                                               3, 3, 3, 3, 3, 3, 3,
                                               3, 3, 3, 3, 3, 3, 3,
                                               1, 1, 1, 1, 1, 1, 1,
                                               1, 1, 1, 1, 1, 1, 1,
                                               1, 1, 1, 1, 1, 1, 1};

double getCenter(Interval a);

double getRadius(Interval a);

class Monomial {
public:
    Eigen::MatrixXd coeff;
    uint64_t degree = 0; // one hash unsigned integer for degrees for all factors, _K4_ _K3_ _K2_ _K1_

    Monomial(Eigen::MatrixXd coeff_inp, uint64_t degree_inp) : coeff(coeff_inp), degree(degree_inp) {};

    Monomial(double coeff_inp, uint64_t degree_inp) : degree(degree_inp) {
        coeff.resize(1,1);
        coeff(0) = coeff_inp;
    };
} ;

class PZsparse {
public:
    // number of rows
    uint NRows = 0;

    // number of columns
    uint NCols = 0;

    // center
    Eigen::MatrixXd center = Eigen::Matrix<double,1,1>::Zero();

    // a vector of monomials for polynomial part
    vector<Monomial> polynomial;

    // intervals centered at 0 as independent generators
    // here we only store the upper bound of the intervals 
    // the actual interval is (-independent,independent)
    Eigen::MatrixXd independent = Eigen::Matrix<double,1,1>::Zero();

    // intermediate helper variable
    uint64_t degreeArray[NUM_FACTORS * 6] = {0};

    /*
    Initialization
    */

    PZsparse() {};

    PZsparse(uint NRows_inp, uint NCols_inp);

    PZsparse(const PZsparse& pz_inp);

    PZsparse(double center_inp);

    PZsparse(const Eigen::MatrixXd& center_inp);

    PZsparse(double center_inp, double uncertainty_percent);

    // PZsparse(Interval interval_inp);

    PZsparse(double center_inp, Interval independent_inp);

    PZsparse(double center_inp, double* coeff_inp, uint64_t degree_inp[][NUM_FACTORS * 6], uint num_monomials);

    // PZsparse(const Eigen::MatrixXd& center_inp, const Eigen::Array<Eigen::MatrixXd>& coeff_inp, uint64_t degree_inp[][NUM_FACTORS * 6], uint num_monomials);

    PZsparse(double center_inp, double* coeff_inp, uint64_t degree_inp[][NUM_FACTORS * 6], uint num_monomials, Interval independent_inp);

    // PZsparse(const Eigen::MatrixXd& center_inp, const Eigen::Array<Eigen::MatrixXd>& coeff_inp, uint64_t degree_inp[][NUM_FACTORS * 6], uint num_monomials, Interval independent_inp);

    PZsparse(const double roll, const double pitch, const double yaw);

    PZsparse(double cos_center_inp, double* cos_coeff_inp, uint64_t cos_degree_inp[][NUM_FACTORS * 6], uint cos_num_monomials,
             double sin_center_inp, double* sin_coeff_inp, uint64_t sin_degree_inp[][NUM_FACTORS * 6], uint sin_num_monomials,
             const uint axis);

    ~PZsparse() = default;

    /*
    Internal functions
    */

    void makeRotationMatrix(Eigen::MatrixXd& R, const double cos_elt, const double sin_elt, const uint axis, bool startFromZero = false);

    bool checkDimensions();

    void simplify();

    void reduce();

    MatrixXInt slice(const double* factor);

    void slice(Eigen::Array<Eigen::MatrixXd, NUM_FACTORS, 1>& gradient, const double* factor); // 1st-order gradient of slice

    // Interval toInterval();

    void convertHashToDegree(const uint64_t degree);

    /*
    Arithmetic
    */

    PZsparse operator=(const double a);
    
    // PZsparse operator=(const Interval& a);

    PZsparse operator=(const PZsparse& a);

    PZsparse operator-();

    PZsparse operator+(const PZsparse& a);

    PZsparse operator+(const double a);

    PZsparse operator+=(const PZsparse& a);

    PZsparse operator-(const PZsparse& a);

    PZsparse operator-(const double a);

    PZsparse operator*(const PZsparse& a);

    PZsparse operator*(const double a);

    PZsparse operator/(const double a);

    PZsparse transpose();
};

uint64_t convertDegreeToHash(const uint64_t* degreeArray);

std::ostream& operator<<(std::ostream& os, PZsparse& a);

/*
Arithmetic
*/

PZsparse operator+(const double a, const PZsparse& b);

PZsparse operator-(const double a, const PZsparse& b);

PZsparse operator*(const double a, const PZsparse& b);

#endif