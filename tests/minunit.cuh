// Minimalistic testing framework ripped off "Learn C the Hard Way", that took
// it from http://www.jera.com/techinfo/jtns/jtn002.html with a dash of NumPy :-)
#include <stdio.h>
#include <assert.h>


#define MU_ISCLOSE(a, b) fabs(a - b) <= 1e-6 + 1e-3*fabs(b)

#define MU_ASSERT(message, test) do { if (!(test)) return message; } while (0)

#define MU_RUN_TEST(test) do { auto *message = test(); tests_run++; \
    if (message) return message; } while (0)

#define MU_RUN_SUITE(suite) \
    int main(int argc, char **argv) { \
        auto *result = suite(); \
        if (result != 0) { \
            printf("ERROR: %s\n", result); \
        } else { \
            printf("ALL TESTS PASSED\n"); \
        } \
        printf("Tests run: %d\n", tests_run); \
        return result != 0; \
    }

auto tests_run = 0;


template<typename Pt, int N_MAX, template<typename, int> class Solver>
float3 center_of_mass(Solution<Pt, N_MAX, Solver>& X, int n_cells = N_MAX) {
    assert(n_cells <= N_MAX);
    auto com = float3{0, 0, 0};
    for (auto i = 0; i < n_cells; i++) {
        com.x += X[i].x/n_cells;
        com.y += X[i].y/n_cells;
        com.z += X[i].z/n_cells;
    }
    return com;
}
